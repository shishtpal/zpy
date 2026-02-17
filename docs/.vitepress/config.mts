import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'ZPy',
  description: 'A Python-like language interpreter written in Zig',
  lang: 'en-US',

  // Base URL for GitHub Pages deployment
  // Change 'zpy' to your repo name if different
  base: '/zpy/',

  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }]
  ],

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: 'Guide', link: '/guide/getting-started', activeMatch: '/guide/' },
      { text: 'Language', link: '/language/syntax', activeMatch: '/language/' },
      { text: 'Reference', link: '/reference/builtins', activeMatch: '/reference/' }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Compiling Scripts', link: '/guide/compiling' },
            { text: 'REPL', link: '/guide/repl' }
          ]
        }
      ],
      '/language/': [
        {
          text: 'Language',
          items: [
            { text: 'Syntax', link: '/language/syntax' },
            { text: 'Data Types', link: '/language/types' },
            { text: 'Operators', link: '/language/operators' },
            { text: 'Control Flow', link: '/language/control-flow' },
            { text: 'Functions', link: '/language/functions' }
          ]
        }
      ],
      '/reference/': [
        {
          text: 'Reference',
          items: [
            { text: 'Built-in Functions', link: '/reference/builtins' },
            { text: 'File System', link: '/reference/filesystem' },
            { text: 'OS Module', link: '/reference/os' },
            { text: 'Math Module', link: '/reference/math' },
            { text: 'JSON', link: '/reference/json' },
            { text: 'CSV', link: '/reference/csv' },
            { text: 'YAML', link: '/reference/yaml' },
            { text: 'HTTP', link: '/reference/http' },
            { text: 'CLI Reference', link: '/reference/cli' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/shishtpal/zpy' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024-present ZPy contributors'
    },

    search: {
      provider: 'local'
    },

    outline: {
      level: [2, 3]
    }
  }
})
