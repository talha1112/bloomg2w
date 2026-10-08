import { defineSecret } from "firebase-functions/params";

export const zoomAccountId = defineSecret("ZOOM_ACCOUNT_ID");
export const zoomClientId = defineSecret("ZOOM_CLIENT_ID");
export const zoomClientSecret = defineSecret("ZOOM_CLIENT_SECRET");

interface ZoomTokenResponse {
  access_token: string;
  expires_in: number;
}

// Zoom's Server-to-Server OAuth tokens are short-lived (1 hour). We fetch a
// fresh one per function invocation rather than caching across invocations —
// Cloud Functions instances are ephemeral and a cached token could outlive
// its validity across cold starts, causing confusing intermittent failures.
async function fetchAccessToken(): Promise<string> {
  const accountId = zoomAccountId.value();
  const clientId = zoomClientId.value();
  const clientSecret = zoomClientSecret.value();

  const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const response = await fetch(
    `https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${encodeURIComponent(accountId)}`,
    {
      method: "POST",
      headers: { Authorization: `Basic ${basicAuth}` },
    }
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Zoom OAuth token request failed (${response.status}): ${body}`);
  }

  const data = (await response.json()) as ZoomTokenResponse;
  return data.access_token;
}

export interface ZoomParticipant {
  id: string; // Zoom's participant UUID for this session — not stable across meetings
  user_email?: string;
  name: string;
  join_time: string; // ISO 8601
  leave_time: string; // ISO 8601
}

export interface ZoomPastMeeting {
  uuid: string;
  duration: number; // minutes
  start_time: string;
  end_time: string;
}

async function zoomGet<T>(path: string, accessToken: string): Promise<T> {
  const response = await fetch(`https://api.zoom.us/v2${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Zoom API request to ${path} failed (${response.status}): ${body}`);
  }
  return (await response.json()) as T;
}

async function zoomPost<T>(path: string, accessToken: string, body: unknown): Promise<T> {
  const response = await fetch(`https://api.zoom.us/v2${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Zoom API request to ${path} failed (${response.status}): ${text}`);
  }
  return (await response.json()) as T;
}

export interface ZoomCreatedMeeting {
  id: number;
  join_url: string;
  start_url: string;
  password: string;
  host_email: string;
}

/**
 * Creates a scheduled meeting under a specific licensed Zoom user (the
 * assigned speaker), so that user is the meeting's host and the meeting
 * appears in their own Zoom account. Requires the speaker to already be a
 * licensed user on the same Zoom account as this Server-to-Server app —
 * this call cannot create a meeting for an external/personal Zoom account.
 *
 * Requires the `meeting:write:meeting:admin` scope on the Zoom app (not
 * needed for attendance sync — grant it separately if meeting creation is
 * enabled).
 */
export async function createMeetingForUser(params: {
  hostEmail: string;
  topic: string;
  /** Local wall-clock time with NO "Z"/offset suffix, e.g. "2026-03-05T18:00:00" — interpreted in `timezone` below, not UTC. */
  startTimeLocal: string;
  /** IANA timezone name the wall-clock time above should be interpreted in. */
  timezone: string;
  durationMinutes: number;
}): Promise<ZoomCreatedMeeting> {
  const token = await fetchAccessToken();
  return zoomPost<ZoomCreatedMeeting>(`/users/${encodeURIComponent(params.hostEmail)}/meetings`, token, {
    topic: params.topic,
    type: 2, // scheduled meeting
    start_time: params.startTimeLocal,
    duration: params.durationMinutes,
    timezone: params.timezone,
    settings: {
      join_before_host: false,
      waiting_room: true,
      approval_type: 2, // no registration required
    },
  });
}

/**
 * Fetches the past meeting's summary (duration, start/end) — used as the
 * denominator for attendance-percentage calculation.
 */
export async function fetchPastMeeting(meetingId: string): Promise<ZoomPastMeeting> {
  const token = await fetchAccessToken();
  return zoomGet<ZoomPastMeeting>(`/past_meetings/${encodeURIComponent(meetingId)}`, token);
}

/**
 * Fetches every participant record for a past meeting, following
 * pagination. A single person who joined/left multiple times appears as
 * multiple records sharing the same email or name — the caller is
 * responsible for grouping and summing intervals.
 */
export async function fetchPastMeetingParticipants(meetingId: string): Promise<ZoomParticipant[]> {
  const token = await fetchAccessToken();
  const participants: ZoomParticipant[] = [];
  let nextPageToken = "";

  do {
    const query = new URLSearchParams({ page_size: "300" });
    if (nextPageToken) query.set("next_page_token", nextPageToken);
    const page = await zoomGet<{ participants: ZoomParticipant[]; next_page_token?: string }>(
      `/past_meetings/${encodeURIComponent(meetingId)}/participants?${query.toString()}`,
      token
    );
    participants.push(...page.participants);
    nextPageToken = page.next_page_token ?? "";
  } while (nextPageToken);

  return participants;
}
