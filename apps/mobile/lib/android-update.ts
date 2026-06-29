export type AndroidUpdateMetadata = {
  versionCode: number;
  versionName: string;
  packageId: string;
  commit: string;
  branch: string;
  builtAt: string;
  apk: string;
};

type FetchLike = (url: string, init?: { headers?: Record<string, string> }) => Promise<{
  ok: boolean;
  status: number;
  json: () => Promise<unknown>;
}>;

const DEFAULT_REPO = "eiei114/multica";

export function normalizeAndroidUpdateRepo(repo: string | undefined): string {
  const trimmed = repo?.trim();
  return trimmed || DEFAULT_REPO;
}

export function androidUpdateMetadataUrl(repo: string | undefined): string {
  return `https://github.com/${normalizeAndroidUpdateRepo(repo)}/releases/latest/download/android-update.json`;
}

export function androidApkDownloadUrl(repo: string | undefined, apk: string): string {
  return `https://github.com/${normalizeAndroidUpdateRepo(repo)}/releases/latest/download/${encodeURIComponent(apk)}`;
}

export function parseAndroidBuildNumber(build: string | null | undefined): number {
  if (!build) return 0;
  const parsed = Number.parseInt(build, 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function isNewerAndroidBuild(
  currentBuild: string | null | undefined,
  latestVersionCode: number,
): boolean {
  return latestVersionCode > parseAndroidBuildNumber(currentBuild);
}

export function parseAndroidUpdateMetadata(value: unknown): AndroidUpdateMetadata {
  if (!value || typeof value !== "object") {
    throw new Error("Invalid update metadata");
  }

  const record = value as Record<string, unknown>;
  const versionCode = record.versionCode;
  const versionName = record.versionName;
  const packageId = record.packageId;
  const commit = record.commit;
  const branch = record.branch;
  const builtAt = record.builtAt;
  const apk = record.apk;

  if (
    typeof versionCode !== "number" ||
    !Number.isFinite(versionCode) ||
    typeof versionName !== "string" ||
    typeof packageId !== "string" ||
    typeof commit !== "string" ||
    typeof branch !== "string" ||
    typeof builtAt !== "string" ||
    typeof apk !== "string" ||
    apk.length === 0
  ) {
    throw new Error("Invalid update metadata");
  }

  return {
    versionCode,
    versionName,
    packageId,
    commit,
    branch,
    builtAt,
    apk,
  };
}

export async function fetchLatestAndroidUpdateMetadata(
  repo: string | undefined,
  fetchImpl: FetchLike = fetch,
): Promise<AndroidUpdateMetadata> {
  const response = await fetchImpl(androidUpdateMetadataUrl(repo), {
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    throw new Error(`Update check failed (${response.status})`);
  }

  return parseAndroidUpdateMetadata(await response.json());
}

