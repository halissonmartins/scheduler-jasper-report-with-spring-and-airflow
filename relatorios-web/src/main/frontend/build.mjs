/* Esqueleto: prova que o frontend-maven-plugin baixou o Node e executou o build,
   e que a saída é empacotada no jar. Substituído por `ng build` quando o app existir. */
import { mkdirSync, writeFileSync } from 'node:fs';

mkdirSync('dist', { recursive: true });
writeFileSync('dist/index.html',
  '<!doctype html><meta charset="utf-8"><title>relatorios-web</title>' +
  '<p>Esqueleto do frontend. O app Angular entra quando a arquitetura for decidida.</p>\n');
console.log('build do esqueleto: dist/index.html');
