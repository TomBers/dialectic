import { build } from "esbuild";
import { mkdir, readFile, writeFile } from "node:fs/promises";

await mkdir(new URL("./dist/", import.meta.url), { recursive: true });
for (const name of ["preview", "demo"]) {
  const bundle = await build({
    absWorkingDir: new URL(".", import.meta.url).pathname,
    entryPoints: [`ui/${name}.ts`], bundle: true, write: false,
    format: "esm", platform: "browser", target: "es2022", minify: true,
  });
  const template = await readFile(new URL(`./ui/${name}.html`, import.meta.url), "utf8");
  const script = bundle.outputFiles[0].text.replace(/<\/script/gi, "<\\/script");
  await writeFile(new URL(`./dist/${name}.html`, import.meta.url), template.replace("{{SCRIPT}}", () => script));
}
