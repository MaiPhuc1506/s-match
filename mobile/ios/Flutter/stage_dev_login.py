"""Stage only the four Quick Login values in local Dev Hub Simulator builds."""
import base64
import json
import os
from pathlib import Path

env = os.environ
mobile = Path(env["SRCROOT"]).parent
resource = Path(env["TARGET_BUILD_DIR"]) / env["UNLOCALIZED_RESOURCES_FOLDER_PATH"] / "smatch_dev_quick_login.json"
# Incremental builds can reuse the same Runner.app for different entry points.
resource.unlink(missing_ok=True)
target = Path(env.get("FLUTTER_TARGET", "lib/main.dart"))
test_flag = base64.b64encode(b"RUN_DEV_QUICK_LOGIN_UAT=true").decode()
dev = (mobile / target).resolve() == (mobile / "lib/main_dev.dart").resolve()
uat = target.name == "listener.dart" and test_flag in env.get("DART_DEFINES", "").split(",")
config = mobile / ".env.dev-quick-login.json"
if (env["CONFIGURATION"] == "Debug" and env["PLATFORM_NAME"] == "iphonesimulator"
        and (dev or uat) and config.is_file()):
    values = json.loads(config.read_text())
    keys = ("DEV_PLAYER_1_PASSWORD", "DEV_PLAYER_2_PASSWORD", "DEV_PLAYER_3_PASSWORD", "DEV_OWNER_PASSWORD")
    with os.fdopen(os.open(resource, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as output:
        json.dump({key: values[key] for key in keys if isinstance(values.get(key), str)}, output)
