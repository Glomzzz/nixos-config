import { cpSync, existsSync, lstatSync, mkdirSync, readFileSync, readlinkSync, symlinkSync, unlinkSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const PACKAGE_ROOT = '@PACKAGE_ROOT@'
const DSH_BIN = join(PACKAGE_ROOT, 'node_modules/@deepseek-ai/dsh/lib/bin.js')

const plugins = [
  { name: '@liustack/modlens', version: '3.22.1' },
  { name: '@liustack/modsearch', version: '5.8.0' },
  { name: 'dsh-routing-suite', version: '0.1.2' },
  { name: 'openviking-dsh-nix', version: '0.1.0', local: true },
]

function resolveHome() {
  const configured = process.env.DSH_HOME?.trim()
  const value = configured === undefined || configured === '' ? join(homedir(), '.dsh') : configured
  if (value === '~') return homedir()
  if (value.startsWith('~/') || value.startsWith('~\\')) return join(homedir(), value.slice(2))
  return resolve(value)
}

function ensureSymlink(link, target) {
  mkdirSync(dirname(link), { recursive: true })
  let stat
  try {
    stat = lstatSync(link)
  } catch {
    stat = undefined
  }
  if (stat !== undefined) {
    if (!stat.isSymbolicLink()) {
      process.stderr.write(`dsh: keeping existing plugin directory ${link}; remove it to use the bundled version\n`)
      return
    }
    if (readlinkSync(link) === target) return
    unlinkSync(link)
  }
  symlinkSync(target, link, 'junction')
}

function readJson(path, fallback) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    if (error?.code === 'ENOENT') return fallback
    throw new Error(`dsh: failed to read ${path}: ${error}`)
  }
}

function writeJsonIfChanged(path, value, previous) {
  const next = `${JSON.stringify(value, null, 2)}\n`
  if (previous === undefined || `${JSON.stringify(previous, null, 2)}\n` !== next) {
    writeFileSync(path, next)
  }
}

function dependencySpec(plugin) {
  if (!plugin.local) return plugin.version
  return `file:${join(PACKAGE_ROOT, 'node_modules', plugin.name)}`
}

function ensureWebProfile(home) {
  const profileDir = join(home, 'profiles', 'web')
  mkdirSync(profileDir, { recursive: true })
  const manifestPath = join(profileDir, 'package.json')
  const manifest = readJson(manifestPath, {
    name: 'dsh-profile-web',
    private: true,
    dependencies: {},
    dsh: { profile: { bundles: ['@deepseek-ai/dsh-base', '@deepseek-ai/dsh-web-app'] } },
  })
  const previous = JSON.parse(JSON.stringify(manifest))
  manifest.dependencies ??= {}
  manifest.dsh ??= {}
  manifest.dsh.profile ??= {}
  manifest.dsh.profile.bundles ??= []
  for (const plugin of plugins) {
    manifest.dependencies[plugin.name] = dependencySpec(plugin)
    if (!manifest.dsh.profile.bundles.includes(plugin.name)) {
      manifest.dsh.profile.bundles.push(plugin.name)
    }
  }
  writeJsonIfChanged(manifestPath, manifest, previous)

  const patchPath = join(profileDir, 'cordis.patch.yml')
  if (!existsSync(patchPath)) writeFileSync(patchPath, '[]\n')
  const workspacePath = join(profileDir, 'pnpm-workspace.yaml')
  if (!existsSync(workspacePath)) {
    writeFileSync(workspacePath, 'packages:\n  - .\n\nnodeLinker: hoisted\nautoInstallPeers: false\n')
  }

  for (const plugin of plugins) {
    const target = join(PACKAGE_ROOT, 'node_modules', plugin.name)
    if (!existsSync(join(target, 'package.json'))) {
      throw new Error(`dsh: bundled plugin is missing from ${target}`)
    }
    ensureSymlink(join(profileDir, 'node_modules', plugin.name), target)
  }

  const routingPreset = join(PACKAGE_ROOT, 'node_modules/dsh-routing-suite/preset/routing-suite')
  const userPreset = join(home, '.agent-presets/routing-suite')
  if (!existsSync(userPreset)) {
    mkdirSync(dirname(userPreset), { recursive: true })
    cpSync(routingPreset, userPreset, { recursive: true })
  }
}

function shouldPrepareWeb(args) {
  if (process.env.DSH_NIX_DISABLE_AUTO_PROFILE === '1') return false
  if (args[0] === 'web') return true
  const profileFlag = args.indexOf('--profile')
  const webProfile = args.includes('--profile=web') || (profileFlag >= 0 && args[profileFlag + 1] === 'web')
  return webProfile
}

const args = process.argv.slice(2)
if (shouldPrepareWeb(args)) ensureWebProfile(resolveHome())

const child = spawnSync(process.execPath, ['--expose-internals', DSH_BIN, ...args], {
  env: process.env,
  stdio: 'inherit',
})
if (child.error !== undefined) throw new Error('dsh: failed to start the harness', { cause: child.error })
process.exit(child.status ?? 1)
