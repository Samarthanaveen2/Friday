"""Writes the SideStore source (AltStore source format) for one build.
Usage: make_source.py <version> <build> <ipa path> <download url> <out.json>"""
import datetime, json, os, sys

version, build, ipa, url, out = sys.argv[1:6]
repo_raw = "https://raw.githubusercontent.com/Samarthanaveen2/Friday/claude/affectionate-fermat-scvp7y/ios"
source = {
    "name": "Friday",
    "identifier": "com.samarth.friday.source",
    "subtitle": "Voice keyboard and assistant",
    "iconURL": f"{repo_raw}/Friday/Assets.xcassets/AppIcon.appiconset/icon.png",
    "apps": [{
        "name": "Friday",
        "bundleIdentifier": "com.samarth.friday",
        "developerName": "Samartha",
        "subtitle": "Talk, and it types.",
        "localizedDescription": "Friday: voice keyboard and assistant.",
        "iconURL": f"{repo_raw}/Friday/Assets.xcassets/AppIcon.appiconset/icon.png",
        "tintColor": "4338CA",
        "versions": [{
            "version": version,
            "buildVersion": build,
            "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "localizedDescription": f"Build {build}",
            "downloadURL": url,
            "size": os.path.getsize(ipa),
            "minOSVersion": "26.0",
        }],
        "appPermissions": {
            "entitlements": ["com.apple.security.application-groups"],
            "privacy": {
                "NSMicrophoneUsageDescription": "Friday listens only while you dictate or talk to it.",
                "NSSpeechRecognitionUsageDescription": "Friday turns your voice into text on the phone as a fast backup.",
            },
        },
    }],
    "news": [],
}
with open(out, "w") as f:
    json.dump(source, f, indent=2)
