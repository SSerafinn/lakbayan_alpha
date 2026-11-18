import { defineConfig, searchForWorkspaceRoot } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    fs: {
      // Satoshi is loaded straight from the repo's assets/fonts/, the same
      // files the app bundles, rather than a copy that could drift. The dev
      // server refuses anything outside cms/ unless it is listed here; the
      // production build reads the file directly and needs no permission.
      // Only that one folder — not the repo root, which holds config/. The
      // province's logo, for the exhibit labels, is let through by name.
      allow: [
        searchForWorkspaceRoot(process.cwd()),
        '../assets/fonts',
        '../assets/images/EndlessFunCagayan.png',
        // The icons a category added in Settings may use, shared with the app.
        '../design/category-glyphs.json',
      ],
    },
  },
})
