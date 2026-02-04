# ${{ values.name }}

${{ values.description }}

## Getting Started

### Prerequisites

- Node.js 20.x or later
- npm

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

### Build

```bash
npm run build
```

### Test

```bash
npm test
```

### Lint

```bash
npm run lint
```

## Project Structure

```
├── src/
│   ├── index.ts          # Main application entry point
│   └── index.test.ts     # Tests
├── azure-pipelines.yaml  # Azure Pipelines CI configuration
├── catalog-info.yaml     # Backstage component metadata
├── package.json
├── tsconfig.json
└── README.md
```

## CI/CD

This project uses Azure Pipelines for continuous integration. The pipeline runs on every push to `main` and performs:

1. Install dependencies
2. Run linter
3. Run tests
4. Build application
5. Publish artifacts

## Component Registration

This component is registered in Red Hat Developer Hub and can be viewed in the catalog.
