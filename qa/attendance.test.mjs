// Unit tests for the pure attendance matching/percentage logic used by
// syncSessionAttendance. Imports the compiled Cloud Functions module.
import assert from "node:assert/strict";
import { describe, test } from "node:test";
import calc from "../functions/lib/attendanceCalculator.js";

const { matchAttendance } = calc;
const T0 = Date.parse("2026-10-05T22:00:00Z");
const at = (min) => new Date(T0 + min * 60000).toISOString();
const rec = (email, from, to, name = "Someone") => ({ id: "z", user_email: email, name, join_time: at(from), leave_time: at(to) });
const reg = (uid, email) => ({ uid, email });

describe("attendance calculation", () => {
  test("full attendance = 100%, qualified", () => {
    const { matches } = matchAttendance([rec("a@x.com", 0, 60)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendancePercent, 100);
    assert.equal(matches[0].qualified, true);
  });

  test("spec example: 50 of 60 min = 83.3%, qualified at 75%", () => {
    const { matches } = matchAttendance([rec("a@x.com", 0, 50)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendancePercent, 83.3);
    assert.equal(matches[0].qualified, true);
  });

  test("late join: 40 of 60 min = 66.7%, not qualified", () => {
    const { matches } = matchAttendance([rec("a@x.com", 20, 60)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendancePercent, 66.7);
    assert.equal(matches[0].qualified, false);
  });

  test("early leave: 30 of 60 min = 50%, not qualified", () => {
    const { matches } = matchAttendance([rec("a@x.com", 0, 30)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].qualified, false);
  });

  test("multiple join/leave intervals are summed", () => {
    const { matches } = matchAttendance([rec("a@x.com", 0, 20), rec("a@x.com", 25, 60)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendedMinutes, 55);
    assert.equal(matches[0].intervalCount, 2);
    assert.equal(matches[0].qualified, true);
  });

  test("overlapping connections (two devices at once) are not double-counted", () => {
    // Joined on phone AND laptop for the same first 30 minutes of a 60-min
    // meeting, then left. True attendance is 30 min (50%), not 60 (100%).
    const { matches } = matchAttendance([rec("a@x.com", 0, 30), rec("a@x.com", 0, 30)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendedMinutes, 30);
    assert.equal(matches[0].attendancePercent, 50);
    assert.equal(matches[0].qualified, false);
  });

  test("partially overlapping reconnect is merged correctly", () => {
    // 0-35 and 30-60 overlap by 5 min -> 60 unique minutes.
    const { matches } = matchAttendance([rec("a@x.com", 0, 35), rec("a@x.com", 30, 60)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendedMinutes, 60);
    assert.equal(matches[0].attendancePercent, 100);
  });

  test("email matching is case-insensitive", () => {
    const { matches } = matchAttendance([rec("A@X.COM", 0, 60)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].matchMethod, "email");
    assert.equal(matches[0].qualified, true);
  });

  test("registrant who never joined is unmatched and not qualified", () => {
    const { matches } = matchAttendance([], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].matchMethod, "unmatched");
    assert.equal(matches[0].qualified, false);
  });

  test("Zoom guest with no email is never auto-matched by name", () => {
    const { matches, unmatched } = matchAttendance([rec(undefined, 0, 60, "Amara")], [reg("a", "amara@x.com")], 60, 75);
    assert.equal(matches[0].matchMethod, "unmatched");
    assert.equal(matches[0].qualified, false);
    assert.equal(unmatched.length, 1);
  });

  test("non-registered Zoom attendee is reported as unmatched", () => {
    const { unmatched } = matchAttendance([rec("stranger@x.com", 0, 60)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(unmatched.length, 1);
    assert.equal(unmatched[0].email, "stranger@x.com");
  });

  test("zero/invalid meeting duration qualifies nobody", () => {
    const { matches } = matchAttendance([rec("a@x.com", 0, 60)], [reg("a", "a@x.com")], 0, 0);
    assert.equal(matches[0].qualified, false);
  });

  test("qualification uses the same rounded value that is stored", () => {
    // 44.98 / 60 = 74.97% -> stored as 75.0 -> must qualify at 75%.
    const { matches } = matchAttendance([rec("a@x.com", 0, 44.98)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendancePercent, 75);
    assert.equal(matches[0].qualified, true);
  });

  test("attendance is capped at 100%", () => {
    const { matches } = matchAttendance([rec("a@x.com", -5, 70)], [reg("a", "a@x.com")], 60, 75);
    assert.equal(matches[0].attendancePercent, 100);
  });
});
