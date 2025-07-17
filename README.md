# Savings App - Spending Tracker

A minimalistic React web application for tracking your spending with categories, amounts, and notes. Changing to trigger a build, hopefully.

[![CI](https://github.com/luisejroblesci/savings-app/actions/workflows/ci.yml/badge.svg)](https://github.com/luisejroblesci/savings-app/actions/workflows/ci.yml)

## Features

### Current Features ✅
- **Add Spending**: Add new expenses with category, amount, currency, and optional notes
- **Categories**: Choose from General, Personal, Auto, or House
- **Currency Support**: Toggle between MXN and USD
- **Notes**: Add optional notes (max 140 characters)
- **Spending List**: View all your recorded expenses
- **Category Filtering**: Filter expenses by category with totals

### Future Features 🚧
The following features have comprehensive test coverage but are not yet implemented:
- **Delete/Edit Functionality**: Modify or remove existing expenses
- **Data Persistence**: Save expenses to localStorage
- **Search**: Search through expenses by notes/content
- **Budget Limits**: Set monthly budgets with warnings
- **CSV Import/Export**: Import/export expense data
- **Accessibility**: Full screen reader and keyboard navigation support
- **Offline Support**: Work without internet connection
- **Multi-language**: Spanish localization
- **Performance**: Virtualized lists for large datasets

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the development server:
   ```bash
   npm run dev
   ```

3. Open your browser and go to `http://localhost:3000`

## Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm test` - Run tests in watch mode
- `npm run test:ui` - Run tests with UI
- `npm run test:coverage` - Generate test coverage report

## Testing

This project uses Vitest and React Testing Library for testing. The test suite includes:

### Passing Tests ✅
- Component rendering and form interactions
- Input validation and state management
- Currency toggling and category selection
- Spending list display and filtering

### Failing Tests (By Design) ❌
- Tests for future features that serve as specifications
- Located in `*.failing.test.jsx` files
- Represent development roadmap and feature requirements
- **Expected to fail** until features are implemented

To run tests:
```bash
# Run all tests (including failing ones)
npm test

# Run only passing tests
npm test -- src/App.test.jsx

# Run with coverage
npm run test:coverage
```

## CI/CD

This project uses GitHub Actions for continuous integration:

- **Automated Testing**: Runs on every push and pull request
- **Multi-Node Testing**: Tests against Node.js 18.x and 20.x
- **Build Verification**: Ensures the app builds successfully
- **Security Auditing**: Checks for package vulnerabilities
- **Test Coverage**: Generates and uploads coverage reports

## Technologies Used

- **Frontend**: React 18, Vite
- **Testing**: Vitest, React Testing Library, @testing-library/jest-dom
- **CI/CD**: GitHub Actions
- **Styling**: Vanilla CSS (no external CSS frameworks)

## Development Workflow

1. **Feature Development**: Look at failing tests in `*.failing.test.jsx` files to understand requirements
2. **TDD Approach**: Implement features to make the failing tests pass
3. **Testing**: Ensure all existing tests continue to pass
4. **CI/CD**: GitHub Actions will run tests and build checks automatically

## Usage

1. Select a category from the dropdown (General, Personal, Auto, House)
2. Enter the amount (numbers only, $ symbol is automatically added)
3. Toggle between MXN and USD currency
4. Optionally add a note (up to 140 characters)
5. Click "Add Spending" to save
6. View your spending list below the form
7. Use category filter to view specific spending categories

## Contributing

1. Check the failing tests to understand feature requirements
2. Implement features following the test specifications
3. Ensure all existing tests continue to pass
4. GitHub Actions will automatically run the test suite

## Project Structure

```
src/
├── App.jsx                     # Main application component
├── App.test.jsx               # Passing tests for current functionality
├── App.failing.test.jsx       # Failing tests for future features
├── EdgeCases.failing.test.jsx # Advanced feature specifications
├── main.jsx                   # Application entry point
└── test/
    └── setup.js              # Test configuration
``` 
