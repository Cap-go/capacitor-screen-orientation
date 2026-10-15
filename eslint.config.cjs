const ionic = require('@ionic/eslint-config/recommended');

module.exports = [
  {
    ignores: [
      'build/**',
      'dist/**',
      'node_modules/**',
      '**/build/**',
      '**/android/app/src/main/assets/**',
      'eslint.config.cjs',
    ],
  },
  ...ionic,
];
