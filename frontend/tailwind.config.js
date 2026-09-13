/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        eclipse: {
          950: '#07090e',
          900: '#0c1017',
          800: '#151b26',
          700: '#1f2937',
          600: '#374151',
          gold: '#f59e0b',
          verdant: '#10b981',
          crimson: '#ef4444',
          void: '#8b5cf6',
          arcane: '#06b6d4',
          ashen: '#f97316',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      }
    },
  },
  plugins: [],
};
