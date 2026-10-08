import { ZoomParticipant } from "./zoomClient";

export interface RegisteredParticipant {
  uid: string;
  email: string; // the Bloom account's own email, lowercased for matching
}

export interface MatchedAttendance {
  uid: string;
  matchMethod: "email" | "name" | "unmatched";
  attendedMinutes: number;
  intervalCount: number;
  attendancePercent: number;
  qualified: boolean;
}

export interface UnmatchedZoomParticipant {
  name: string;
  email?: string;
  totalMinutes: number;
}

/**
 * Total unique minutes covered by a set of [start, end] millisecond
 * intervals. Overlaps are merged rather than summed — Zoom emits one
 * record per connection, so a participant joined from two devices at once
 * (or whose reconnect overlaps the previous connection) would otherwise be
 * credited for the same wall-clock minutes twice.
 */
function uniqueMinutes(intervals: Array<[number, number]>): number {
  const sorted = intervals.filter(([s, e]) => e > s).sort((a, b) => a[0] - b[0]);
  let totalMs = 0;
  let curStart = -Infinity;
  let curEnd = -Infinity;
  for (const [s, e] of sorted) {
    if (s > curEnd) {
      if (curEnd > curStart) totalMs += curEnd - curStart;
      curStart = s;
      curEnd = e;
    } else if (e > curEnd) {
      curEnd = e;
    }
  }
  if (curEnd > curStart) totalMs += curEnd - curStart;
  return totalMs / 60000;
}

/**
 * Groups a flat list of Zoom participant join/leave records (one record per
 * join, so a participant who reconnected appears multiple times) by their
 * best-available identity key, and computes their total unique attended
 * minutes across every interval.
 */
function groupByIdentity(participants: ZoomParticipant[]): Map<string, { name: string; email?: string; totalMinutes: number; intervalCount: number }> {
  const intervalsByKey = new Map<string, { name: string; email?: string; intervals: Array<[number, number]> }>();

  for (const p of participants) {
    const email = p.user_email?.trim().toLowerCase();
    const key = email && email.length > 0 ? `email:${email}` : `name:${p.name.trim().toLowerCase()}`;
    const interval: [number, number] = [new Date(p.join_time).getTime(), new Date(p.leave_time).getTime()];

    const existing = intervalsByKey.get(key);
    if (existing) {
      existing.intervals.push(interval);
    } else {
      intervalsByKey.set(key, { name: p.name, email, intervals: [interval] });
    }
  }

  const groups = new Map<string, { name: string; email?: string; totalMinutes: number; intervalCount: number }>();
  for (const [key, entry] of intervalsByKey) {
    groups.set(key, { name: entry.name, email: entry.email, totalMinutes: uniqueMinutes(entry.intervals), intervalCount: entry.intervals.length });
  }
  return groups;
}

/**
 * Matches Zoom's attendance report against Bloom's registered participants
 * and calculates each one's attendance percentage and qualification.
 *
 * Matching priority (per program direction — participants join Zoom logged
 * into an account whose email matches their Bloom account):
 *   1. Email match (reliable — Zoom's authenticated participant email)
 *   2. Name match (fallback only, flagged for admin review)
 *   3. No match — never auto-qualifies, never auto-awards a badge
 *
 * `sessionDurationMinutes` is the authoritative denominator (the actual
 * Zoom meeting length), not merely the longest single participant's time,
 * so a participant who left early is correctly penalized.
 */
export function matchAttendance(
  zoomParticipants: ZoomParticipant[],
  registered: RegisteredParticipant[],
  sessionDurationMinutes: number,
  minAttendancePercent: number
): { matches: MatchedAttendance[]; unmatched: UnmatchedZoomParticipant[] } {
  const grouped = groupByIdentity(zoomParticipants);
  const matches: MatchedAttendance[] = [];
  const consumedKeys = new Set<string>();

  // A meeting Zoom reports as 0 minutes long (or a missing/invalid
  // duration) cannot support a meaningful percentage — treating that as
  // "0 required, 0 attended, therefore qualified" would silently mark
  // every registrant attended. Surface it as entirely unmatched/
  // unqualified instead, forcing an admin to investigate rather than
  // trusting a bad denominator.
  const hasValidDuration = sessionDurationMinutes > 0;

  for (const reg of registered) {
    const emailKey = `email:${reg.email.trim().toLowerCase()}`;
    const emailEntry = grouped.get(emailKey);

    let matchMethod: MatchedAttendance["matchMethod"] = "unmatched";
    let totalMinutes = 0;
    let intervalCount = 0;

    if (emailEntry) {
      matchMethod = "email";
      totalMinutes = emailEntry.totalMinutes;
      intervalCount = emailEntry.intervalCount;
      consumedKeys.add(emailKey);
    }
    // Name-based fallback is deliberately not attempted automatically here:
    // Bloom's own registration record does not reliably carry a display
    // name that matches Zoom's, and a silent name match risks crediting
    // the wrong person. Unmatched registrants surface to the admin for
    // manual review/correction instead (see recordZoomSync in index.ts).

    const rawPercent = hasValidDuration ? Math.min(100, (totalMinutes / sessionDurationMinutes) * 100) : 0;
    // Round once and qualify against that SAME rounded value — comparing
    // qualification against the unrounded percent while persisting the
    // rounded one could show e.g. "75.0%" as not-qualified against a 75%
    // threshold when the true value was 74.96%, which rounds to 75.0.
    const attendancePercent = Math.round(rawPercent * 10) / 10;

    matches.push({
      uid: reg.uid,
      matchMethod,
      attendedMinutes: Math.round(totalMinutes * 10) / 10,
      intervalCount,
      attendancePercent,
      qualified: hasValidDuration && matchMethod !== "unmatched" && attendancePercent >= minAttendancePercent,
    });
  }

  const unmatched: UnmatchedZoomParticipant[] = [];
  for (const [key, entry] of grouped.entries()) {
    if (!consumedKeys.has(key)) {
      unmatched.push({ name: entry.name, email: entry.email, totalMinutes: Math.round(entry.totalMinutes * 10) / 10 });
    }
  }

  return { matches, unmatched };
}
