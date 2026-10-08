// Do the app's "does my doc exist yet?" reads (a get() on a NOT-YET-
// EXISTING doc the participant would own) pass the security rules?
import { readFileSync } from "node:fs";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, onSnapshot, setDoc, Timestamp } from "firebase/firestore";

const env = await initializeTestEnvironment({ projectId: "demo-bloomg2w", firestore: { rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8") } });
await env.withSecurityRulesDisabled(async (ctx) => {
  await setDoc(doc(ctx.firestore(), "users", "p1"), { role: "member", email: "p1@example.com" });
});
const db = env.authenticatedContext("p1", { email: "p1@example.com" }).firestore();

const checks = {
  "session_registrations (registerForSession / fetchRegistration)": "sessX_p1",
  "session_checkins (fetchCheckin)": "sessX_p1",
  "session_surveys (fetchSurvey / submitExitSurvey)": "sessX_p1",
  "session_badges (submitExitSurvey badge-exists check)": "sessX_p1",
};
for (const [label, id] of Object.entries(checks)) {
  const coll = label.split(" ")[0];
  try { const s = await getDoc(doc(db, coll, id)); console.log(`ALLOW get()  ${label} -> exists=${s.exists()}`); }
  catch (e) { console.log(`DENY  get()  ${label}: ${e.code}`); }
}
// watchRegistration() in SessionDetailScreen is a snapshot listener on the same doc
await new Promise((resolve) => {
  const unsub = onSnapshot(doc(db, "session_registrations", "sessX_p1"),
    (s) => { console.log(`ALLOW listen session_registrations -> exists=${s.exists()}`); unsub(); resolve(); },
    (e) => { console.log(`DENY  listen session_registrations: ${e.code}`); resolve(); });
});
await env.cleanup();
