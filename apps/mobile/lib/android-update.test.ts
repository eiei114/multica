import { describe, expect, it } from "vitest";
import {
  androidApkDownloadUrl,
  androidUpdateMetadataUrl,
  isNewerAndroidBuild,
  normalizeAndroidUpdateRepo,
  parseAndroidBuildNumber,
  parseAndroidUpdateMetadata,
} from "./android-update";

describe("android update metadata helpers", () => {
  it("normalizes the private fork repo default", () => {
    expect(normalizeAndroidUpdateRepo(undefined)).toBe("eiei114/multica");
    expect(normalizeAndroidUpdateRepo("  ")).toBe("eiei114/multica");
    expect(normalizeAndroidUpdateRepo("owner/repo")).toBe("owner/repo");
  });

  it("builds latest release metadata and APK URLs", () => {
    expect(androidUpdateMetadataUrl("owner/repo")).toBe(
      "https://github.com/owner/repo/releases/latest/download/android-update.json",
    );
    expect(androidApkDownloadUrl("owner/repo", "multica android.apk")).toBe(
      "https://github.com/owner/repo/releases/latest/download/multica%20android.apk",
    );
  });

  it("compares native build numbers defensively", () => {
    expect(parseAndroidBuildNumber("42")).toBe(42);
    expect(parseAndroidBuildNumber("42-custom")).toBe(42);
    expect(parseAndroidBuildNumber(undefined)).toBe(0);
    expect(isNewerAndroidBuild("41", 42)).toBe(true);
    expect(isNewerAndroidBuild("42", 42)).toBe(false);
  });

  it("parses valid update metadata", () => {
    expect(
      parseAndroidUpdateMetadata({
        versionCode: 12,
        versionName: "0.1.0-android.12",
        packageId: "ai.multica.mobile.eiei114",
        commit: "abcdef",
        branch: "android-build",
        builtAt: "2026-06-30T00:00:00.000Z",
        apk: "multica-android-12.apk",
      }),
    ).toMatchObject({ versionCode: 12, apk: "multica-android-12.apk" });
  });

  it("rejects malformed metadata", () => {
    expect(() => parseAndroidUpdateMetadata({ versionCode: "12" })).toThrow(
      "Invalid update metadata",
    );
  });
});

