// Mechanical image optimization. Run from the repo root with --apply.
// Requires macOS sips/pngcrush, pngquant, Swift, and Node. Originals and a JSON report
// are retained in a unique temporary directory; unchanged/rejected candidates stay untouched.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';

if (!process.argv.includes('--apply')) throw new Error('Pass --apply to optimize app images in place.');
const root = path.resolve('SpringFestivalCrush');
const manifestPath = path.resolve('tools/image-compression-hashes.json');
const previous = fs.existsSync(manifestPath) ? JSON.parse(fs.readFileSync(manifestPath)) : {};
const hashes = {};
const digest = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'spring-image-compression-'));
console.log(`Original backups and report: ${work}`);
const audit = JSON.parse(execFileSync('swift', ['-module-cache-path', '/tmp/spring-image-module-cache', 'tools/audit_images.swift', root], { maxBuffer: 8e6 }));
fs.writeFileSync(path.join(work, 'before.json'), JSON.stringify(audit, null, 2));
const verifier = path.join(work, 'verify');
execFileSync('swiftc', ['-O', '-module-cache-path', '/tmp/spring-image-module-cache', 'tools/verify_image_compression.swift', '-o', verifier]);
const pngcrush = execFileSync('xcrun', ['--find', 'pngcrush'], { encoding: 'utf8' }).trim();
const jpegSets = new Set(['ZodiacFestivalMap.imageset', 'ZodiacFestivalMapExpanded.imageset', 'rat_bg.imageset']);
const report = [];
for (const item of audit) {
  const input = item.path;
  const relative = path.relative(root, input);
  // Prevent cumulative JPEG/quantization loss on repeated runs. Only new/changed
  // source assets are candidates; replacing an asset invalidates its hash.
  const inputHash = digest(input);
  if (previous[relative] === inputHash) {
    hashes[relative] = inputHash;
    report.push({ file: relative, before: item.bytes, after: item.bytes, result: 'already processed' });
    continue;
  }
  const backup = path.join(work, 'originals', relative);
  fs.mkdirSync(path.dirname(backup), { recursive: true });
  fs.copyFileSync(input, backup);
  const png = path.extname(input).toLowerCase() === '.png';
  const convert = png && !item.transparent && jpegSets.has(path.basename(path.dirname(input)));
  const candidates = [];
  function attempt(command, args, candidate) {
    const result = spawnSync(command, args, { encoding: 'utf8' });
    if (result.status === 0 && fs.existsSync(candidate) && fs.statSync(candidate).size < item.bytes) {
      const check = spawnSync(verifier, [input, candidate], { encoding: 'utf8' });
      if (check.status === 0) candidates.push({ path: candidate, bytes: fs.statSync(candidate).size, quality: check.stdout.trim() });
    }
  }
  if (convert || !png) {
    const candidate = path.join(work, 'candidate.jpg');
    fs.rmSync(candidate, { force: true });
    attempt('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', convert ? '76' : '72', input, '--out', candidate], candidate);
  } else {
    const lossless = path.join(work, 'lossless.png');
    fs.rmSync(lossless, { force: true });
    attempt(pngcrush, ['-q', '-rem', 'text', input, lossless], lossless);
    // Do not requantize indexed PNGs or touch precision grid/mask alpha with lossy compression.
    if (fs.readFileSync(input)[25] !== 3 && !relative.includes('Grid.atlas/')) {
      const quantized = path.join(work, 'quantized.png');
      fs.rmSync(quantized, { force: true });
      attempt('pngquant', ['--quality=82-98', '--speed', '1', '--strip', '--force', '--output', quantized, input], quantized);
    }
  }
  candidates.sort((a, b) => a.bytes - b.bytes);
  const best = candidates[0];
  if (!best) {
    hashes[relative] = inputHash;
    report.push({ file: relative, before: item.bytes, after: item.bytes, result: 'kept original' });
    continue;
  }
  const destination = convert ? input.replace(/\.png$/i, '.jpg') : input;
  if (convert) {
    if (fs.existsSync(destination)) throw new Error(`Refusing to overwrite ${destination}`);
    const contentsPath = path.join(path.dirname(input), 'Contents.json');
    const contents = JSON.parse(fs.readFileSync(contentsPath));
    fs.copyFileSync(contentsPath, path.join(path.dirname(backup), 'Contents.json'));
    const entry = contents.images.find(image => image.filename === path.basename(input));
    if (!entry) throw new Error(`No asset reference for ${input}`);
    fs.copyFileSync(best.path, destination);
    entry.filename = path.basename(destination);
    fs.writeFileSync(contentsPath, JSON.stringify(contents, null, 2) + '\n');
    fs.unlinkSync(input); // Exact validated target, original retained above and in Git.
  } else fs.copyFileSync(best.path, destination);
  hashes[path.relative(root, destination)] = digest(destination);
  report.push({ file: relative, output: path.relative(root, destination), before: item.bytes, after: best.bytes, result: best.quality });
  console.log(`${relative}: ${item.bytes} -> ${best.bytes}; ${best.quality}`);
}
fs.writeFileSync(path.join(work, 'report.json'), JSON.stringify(report, null, 2));
fs.writeFileSync(manifestPath, JSON.stringify(hashes, null, 2) + '\n');
const before = report.reduce((n, r) => n + r.before, 0);
const after = report.reduce((n, r) => n + r.after, 0);
console.log(JSON.stringify({ images: report.length, optimized: report.filter(r => r.after < r.before).length, before, after, saved: before - after, work }));
