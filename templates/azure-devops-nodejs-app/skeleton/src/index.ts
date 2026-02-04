/**
 * ${{ values.name }}
 * ${{ values.description }}
 */

interface AppConfig {
  name: string;
  version: string;
  environment: string;
}

function getConfig(): AppConfig {
  return {
    name: '${{ values.name }}',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
  };
}

function main(): void {
  const config = getConfig();
  console.log(`Starting ${config.name} v${config.version}`);
  console.log(`Environment: ${config.environment}`);
  console.log('Application is running!');
}

// Export for testing
export { getConfig, AppConfig };

// Run if executed directly
if (require.main === module) {
  main();
}
