// Learn more https://docs.expo.dev/guides/customizing-metro/
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

// Find the project and workspace directories
const projectRoot = __dirname;

const config = getDefaultConfig(projectRoot);

const root = path.join(projectRoot, '../..');

config.watchFolders = [projectRoot, ...['packages', 'node_modules'].map((v) => path.join(root, v))];

config.resolver.blockList = [
  // Copied from expo-yarn-workspaces
  /\/__tests__\//,
  /\/android\/React(Android|Common)\//,
  /\/versioned-react-native\//,

  /\/expo-router\/node_modules\/@react-navigation/,
  /node_modules\/@react-navigation\/native-stack\/node_modules\/@react-navigation\//,
  /node_modules\/pretty-format\/node_modules\/react-is/,
];

// Copied from expo-yarn-workspaces
config.transformer.enableBabelRCLookup = false;

config.transformer.getTransformOptions = () => ({
  transform: {
    experimentalImportSupport: require('getenv').boolish('EXPO_USE_METRO_REQUIRE', false),
    inlineRequires: false,
  },
});

module.exports = config;
