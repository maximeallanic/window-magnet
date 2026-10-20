// Minimal assertion helper for the headless unit tests (run with: gjs -m tests/unit/<file>.js).
export function eq(actual, expected, name) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        printerr(`FAIL ${name}: ${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
        imports.system.exit(1);
    }
}
