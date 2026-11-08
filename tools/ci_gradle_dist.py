#!/usr/bin/env python3
"""CI helper: pre-seed the Gradle wrapper cache from services.gradle.org.

Godot's Android build template points the Gradle wrapper at a GitHub release URL.
When GitHub's release downloads fail (504s), this downloads the same distribution
from the official Gradle server into the folder the wrapper would use
(~/.gradle/wrapper/dists/<name>/<base36 md5 of the URL>/), so no download is needed.
Usage: ci_gradle_dist.py android/build/gradle/wrapper/gradle-wrapper.properties
"""
import hashlib
import os
import sys
import urllib.request
import zipfile


def base36(n: int) -> str:
    digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    out = ""
    while n:
        n, r = divmod(n, 36)
        out = digits[r] + out
    return out or "0"


def main() -> int:
    props = open(sys.argv[1], encoding="utf-8").read().splitlines()
    url = next(l.split("=", 1)[1] for l in props if l.startswith("distributionUrl")).replace("\\:", ":").strip()
    name = os.path.basename(url)[:-4]                      # gradle-8.11.1-bin
    h = base36(int(hashlib.md5(url.encode()).hexdigest(), 16))
    dest = os.path.join(os.path.expanduser("~"), ".gradle", "wrapper", "dists", name, h)
    os.makedirs(dest, exist_ok=True)
    zpath = os.path.join(dest, name + ".zip")
    src = "https://services.gradle.org/distributions/%s.zip" % name
    print("gradle dist:", url, "->", dest, "from", src)
    urllib.request.urlretrieve(src, zpath)
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest)
    for root, _dirs, files in os.walk(dest):            # zipfile drops the exec bit
        for f in files:
            if root.endswith("bin"):
                os.chmod(os.path.join(root, f), 0o755)
    open(zpath + ".ok", "w").close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
