import axios from "axios";
import * as dayjs from "dayjs";
import { WorkbookJob } from "../modules/workbook-job/workbook-job";
import { WorkbookTimeEntry } from "../modules/workbook-time-entry/workbook-time-entry";

// Necessary, because current workbook server uses old version of TLS
require("tls").DEFAULT_MIN_VERSION = "TLSv1";

export interface WorkbookSession {
  ssPid: string;
  ssId: string;
}

export async function createWorkbookSession(
  username: string,
  password: string,
) {
  const res = await axios.post("https://wbapp.magnetix.dk/api/auth/ldap", {
    UserName: username,
    Password: password,
    RememberMe: true,
  });

  const ssPidRegex = new RegExp("(?<=ss-pid=)(.*?)(?=;)");
  const ssPids = ssPidRegex.exec(res.headers["set-cookie"][0]);
  const ssPid = ssPids && ssPids[0];

  const ssIdRegex = new RegExp("(?<=ss-id=)(.*?)(?=;)");
  const ssIds = ssIdRegex.exec(res.headers["set-cookie"][1]);
  const ssId = ssIds && ssIds[0];
  console.log(ssPid , ssId);
  if (!ssPid || !ssId) {
    throw new Error("Unable to log in");
  }

  return {
    ssPid,
    ssId,
  };
}

function getWorkbookHeaders(session: WorkbookSession) {
  return {
    Cookie: `X-UAId=; ss-opt=perm; ss-pid=${session.ssPid}; ss-id=${session.ssId}`,
  };
}

export async function getWorkbookUser(session: WorkbookSession) {
  const res = await axios.get(
    "https://wbapp.magnetix.dk/api/auth/currentsession",
    {
      headers: getWorkbookHeaders(session),
    },
  );

  return res.data;
}

export async function getTimeEntrySheet(
  session: WorkbookSession,
): Promise<WorkbookTimeEntry[]> {
  const date = dayjs().format("YYYY-MM-DD");

  const res = await axios.get<WorkbookTimeEntry[]>(
    `https://wbapp.magnetix.dk/api/personalexpense/timeentry/visualization/sheet?Date=${date}T00%3A00%3A00.000Z`,
    {
      headers: getWorkbookHeaders(session),
    },
  );

  // For some reason, some entries don't have any ID.
  // We can't use those.
  return res.data.filter((item) => !!item.Id);
}

export async function getJob(session: WorkbookSession, jobId: string) {
  const res = await axios.get<WorkbookJob>(
    `https://wbapp.magnetix.dk/api/job/${jobId}`,
    {
      headers: getWorkbookHeaders(session),
    },
  );

  return res.data;
}

export async function getTimeEntry(
  session: WorkbookSession,
  timeEntryId: string,
) {
  const res = await axios.get(
    `https://wbapp.magnetix.dk/api/personalexpense/timeentry/${timeEntryId}`,
    {
      headers: getWorkbookHeaders(session),
    },
  );
  return res.data;
}
