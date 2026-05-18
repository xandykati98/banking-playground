import fs from "fs";
import path from "path";

const LIB = path.resolve(__dirname, "../../banking_app/lib");

export const LAYOUT_CURRENT = path.join(LIB, "layout/current");
export const LAYOUT_DEFAULTS = path.join(LIB, "layout/defaults");
export const COMPONENTS_CURRENT = path.join(LIB, "components/current");
export const COMPONENTS_DEFAULTS = path.join(LIB, "components/defaults");
export const APP_SHELL_CURRENT = path.join(LIB, "app_shell.dart");
export const APP_SHELL_DEFAULTS = path.join(LIB, "app_shell_defaults.dart");
export const RESET_SENTINEL = path.join(LIB, ".reset");

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
    fs.copyFileSync(
      path.join(defaultsDir, file),
      path.join(currentDir, file)
    );
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

export function resetLayout(): void {
  resetDir(LAYOUT_DEFAULTS, LAYOUT_CURRENT, ".json");
  resetDir(COMPONENTS_DEFAULTS, COMPONENTS_CURRENT, ".dart");
  fs.copyFileSync(APP_SHELL_DEFAULTS, APP_SHELL_CURRENT);
}
