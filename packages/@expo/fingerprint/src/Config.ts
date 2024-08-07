import fs from 'fs/promises';
import path from 'path';

import type { Config } from './Fingerprint.types';

const CONFIG_FILES = ['fingerprint.config.js', 'fingerprint.config.cjs'];

const debug = require('debug')('expo:fingerprint:Config');

/**
 * Load the fingerprint.config.js from project root.
 * @param projectRoot The project root directory.
 * @param silent Whether to mute console logs when loading the config. This is useful for expo-updates integration and makes sure the JSON output is valid.
 * @returns The loaded config or null if no config file was found.
 */
export async function loadConfigAsync(
  projectRoot: string,
  silent: boolean = false
): Promise<Config | null> {
  let configFile: string;
  try {
    configFile = await resolveConfigFileAsync(projectRoot);
  } catch {
    return null;
  }
  debug('Resolved config file:', configFile);

  const unregisterMuteLogs = silent ? muteLogs() : null;
  let rawConfig;
  try {
    rawConfig = require(configFile);
  } catch (e: unknown) {
    debug('Error loading config file:', e);
    rawConfig = {};
  }
  unregisterMuteLogs?.();

  const supportedConfigKeys: (keyof Config)[] = [
    'concurrentIoLimit',
    'hashAlgorithm',
    'extraSources',
    'sourceSkips',
    'enableReactImportsPatcher',
    'debug',
  ];
  const config: Config = {};
  for (const key of supportedConfigKeys) {
    if (key in rawConfig) {
      config[key] = rawConfig[key];
    }
  }
  return config;
}

/**
 * Resolve the config file path from the project root.
 */
async function resolveConfigFileAsync(projectRoot: string): Promise<string> {
  return await Promise.any(
    CONFIG_FILES.map(async (file) => {
      const configPath = path.resolve(projectRoot, file);
      const stat = await fs.stat(configPath);
      if (!stat.isFile()) {
        throw new Error(`Config file is not a file: ${configPath}`);
      }
      return configPath;
    })
  );
}

/**
 * Monkey-patch the console to mute logs.
 * @returns A function to unregister the monkey-patch.
 */
function muteLogs(): () => void {
  const originalConsole = {
    log: console.log,
    warn: console.warn,
    error: console.error,
  };
  const unregister = () => {
    console.log = originalConsole.log;
    console.warn = originalConsole.warn;
    console.error = originalConsole.error;
  };
  console.log = () => {};
  console.warn = () => {};
  console.error = () => {};
  return unregister;
}
