import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { viteSingleFile } from 'vite-plugin-singlefile'

const OUT_DIR = fileURLToPath(new URL('../dn1sup_comp_add_view/resources', import.meta.url))

// Vite сохраняет имя входного файла (index.html) — панель должна называться
// panel.html, чтобы не путаться с потенциальными будущими html-ресурсами.
function renamePanelHtml() {
  return {
    name: 'rename-panel-html',
    closeBundle() {
      const from = path.join(OUT_DIR, 'index.html')
      const to = path.join(OUT_DIR, 'panel.html')
      if (fs.existsSync(from)) fs.renameSync(from, to)
    }
  }
}

// Панель собирается в ОДИН self-contained файл resources/panel.html:
// JS и CSS инлайнятся, чтобы HtmlDialog загружал всё с диска без сети.
// emptyOutDir: false — рядом лежат SVG-иконки тулбара, их стирать нельзя.
export default defineConfig({
  base: './',
  plugins: [vue(), viteSingleFile(), renamePanelHtml()],
  build: {
    outDir: OUT_DIR,
    emptyOutDir: false,
    rollupOptions: {
      input: { panel: fileURLToPath(new URL('./index.html', import.meta.url)) }
    }
  }
})
