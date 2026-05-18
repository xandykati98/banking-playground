import fs from "fs";
import path from "path";

const LIB = path.resolve(__dirname, "../../banking_app/lib");

export const LAYOUT_CURRENT = path.join(LIB, "layout/current");
export const LAYOUT_DEFAULTS = path.join(LIB, "layout/defaults");
export const COMPONENTS_CURRENT = path.join(LIB, "components/current");
export const COMPONENTS_DEFAULTS = path.join(LIB, "components/defaults");
export const APP_SHELL_CURRENT = path.join(LIB, "app_shell.dart");
export const APP_SHELL_DEFAULTS = path.join(LIB, "app_shell_defaults.dart");

// Reads dashboard.json (root props) + all other *.json component files and
// assembles them into the shape Flutter expects:
//   { id, props, children: [...sorted by order] }
export function assembleLayout(dir: string): object {
  const rootPath = path.join(dir, "dashboard.json");
  const root = JSON.parse(fs.readFileSync(rootPath, "utf-8")) as {
    id: string;
    props: Record<string, string>;
  };

  const componentFiles = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".json") && f !== "dashboard.json");

  const children = componentFiles
    .map((f) => JSON.parse(fs.readFileSync(path.join(dir, f), "utf-8")))
    .sort(
      (a: { order?: number }, b: { order?: number }) =>
        (a.order ?? 0) - (b.order ?? 0)
    );

  return { ...root, children };
}

function resetDir(
  defaultsDir: string,
  currentDir: string,
  ext: string
): void {
  const defaultFiles = fs
    .readdirSync(defaultsDir)
    .filter((f) => f.endsWith(ext));

  for (const file of defaultFiles) {
    // Use writeFileSync (not copyFileSync) to guarantee mtime is updated,
    // which forces Flutter's file watcher to detect the change.
    const content = fs.readFileSync(path.join(defaultsDir, file));
    fs.writeFileSync(path.join(currentDir, file), content);
  }

  // Remove any extra files in current that the agent may have created.
  const currentFiles = fs
    .readdirSync(currentDir)
    .filter((f) => f.endsWith(ext));

  for (const file of currentFiles) {
    if (!defaultFiles.includes(file)) {
      fs.unlinkSync(path.join(currentDir, file));
    }
  }
}

// Writes file content via readFileSync+writeFileSync so Node always updates
// the mtime, which forces Flutter's file watcher to detect the change even
// when the content is identical to a previous cached compilation artifact.
function writeWithMtimeUpdate(src: string, dest: string): void {
  const content = fs.readFileSync(src);
  fs.writeFileSync(dest, content);
}

export function resetLayout(): void {
  resetDir(LAYOUT_DEFAULTS, LAYOUT_CURRENT, ".json");
  resetDir(COMPONENTS_DEFAULTS, COMPONENTS_CURRENT, ".dart");
  writeWithMtimeUpdate(APP_SHELL_DEFAULTS, APP_SHELL_CURRENT);
}
