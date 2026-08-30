import { cpSync, existsSync, lstatSync, mkdirSync, readFileSync, readlinkSync, symlinkSync, unlinkSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'

const PACKAGE_ROOT = '@PACKAGE_ROOT@'
const DSH_BIN = join(PACKAGE_ROOT, 'node_modules/@deepseek-ai/dsh/lib/bin.js')
const TUI_LAUNCHER_BIN = join(PACKAGE_ROOT, 'node_modules/@deepseek-harness-tui/dsh-tui/bin/dsh-tui.js')

// Bundled plugins of the web profile, in boot order. Keep versions in sync
// with package.json.
const webPlugins = [
  { name: '@liustack/modlens', version: '3.25.3' },
  { name: '@liustack/modsearch', version: '5.10.0' },
  { name: 'dsh-routing-suite', version: '0.1.2' },
  { name: 'openviking-dsh-nix', version: '0.1.0', local: true },
]

// The TUI profile surface: @deepseek-harness-tui/dsh-tui over dsh-base.
// The profile is named `dsh-tui` because the plugin's own launcher
// (bin/dsh-tui.js) hardcodes that name; its realpath check resolves through
// the store symlink, so the bundled launcher runs its full logic (--resume
// conversion, workspace target, dsh preflight) and delegates to
// `dsh --profile dsh-tui`.
const tuiPlugin = { name: '@deepseek-harness-tui/dsh-tui', version: '0.9.3' }

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

/**
 * Prepare a profile directory under $DSH_HOME: manifest with the bundle
 * list and pinned plugin dependencies, an empty user patch layer, pnpm
 * workspace settings, and store symlinks for every out-of-tree plugin.
 * Existing files are updated in place (versions re-pinned, symlinks
 * re-pointed), so re-running after a package update migrates the profile.
 */
function ensureProfile(home, name, { bundles, plugins }) {
  const profileDir = join(home, 'profiles', name)
  mkdirSync(profileDir, { recursive: true })
  const manifestPath = join(profileDir, 'package.json')
  const manifest = readJson(manifestPath, {
    name: `dsh-profile-${name}`,
    private: true,
    dependencies: {},
    dsh: { profile: { bundles: [...bundles] } },
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
}

function ensureWebProfile(home) {
  ensureProfile(home, 'web', {
    bundles: ['@deepseek-ai/dsh-base', '@deepseek-ai/dsh-web-app'],
    plugins: webPlugins,
  })

  const routingPreset = join(PACKAGE_ROOT, 'node_modules/dsh-routing-suite/preset/routing-suite')
  const userPreset = join(home, '.agent-presets/routing-suite')
  if (!existsSync(userPreset)) {
    mkdirSync(dirname(userPreset), { recursive: true })
    cpSync(routingPreset, userPreset, { recursive: true })
  }
}

function ensureTuiProfile(home) {
  ensureProfile(home, 'dsh-tui', {
    bundles: ['@deepseek-ai/dsh-base'],
    plugins: [tuiPlugin],
  })
}

function shouldPrepareProfiles(args) {
  if (process.env.DSH_NIX_DISABLE_AUTO_PROFILE === '1') return []
  const prepared = []
  const flagValue = (name) => {
    if (args.includes(`--profile=${name}`)) return true
    const profileFlag = args.indexOf('--profile')
    return profileFlag >= 0 && args[profileFlag + 1] === name
  }
  if (args[0] === 'web' || flagValue('web')) prepared.push('web')
  if (args[0] === 'dsh-tui' || flagValue('dsh-tui')) prepared.push('dsh-tui')
  return [...new Set(prepared)]
}

const args = process.argv.slice(2)
const home = resolveHome()

// The dsh-tui wrapper: prepare the TUI profile, then hand the invocation to
// the plugin's own launcher, which implements the upstream argument contract
// (--resume/-c/--continue, workspace target, legacy env warnings) and
// delegates to `dsh --profile dsh-tui`.
if (args[0] === '--tui-launcher') {
  ensureTuiProfile(home)
  const child = spawnSync(process.execPath, ['--expose-internals', TUI_LAUNCHER_BIN, ...args.slice(1)], {
    env: process.env,
    stdio: 'inherit',
  })
  if (child.error !== undefined) throw new Error('dsh-tui: failed to start the launcher', { cause: child.error })
  process.exit(child.status ?? 1)
}

for (const profile of shouldPrepareProfiles(args)) {
  if (profile === 'web') ensureWebProfile(home)
  if (profile === 'dsh-tui') ensureTuiProfile(home)
}

const child = spawnSync(process.execPath, ['--expose-internals', DSH_BIN, ...args], {
  env: process.env,
  stdio: 'inherit',
})
if (child.error !== undefined) throw new Error('dsh: failed to start the harness', { cause: child.error })
process.exit(child.status ?? 1)
