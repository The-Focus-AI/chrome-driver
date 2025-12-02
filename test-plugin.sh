#!/bin/bash
set -e

echo "=== chrome-driver Plugin Test Suite ==="
echo

# 1. Perl unit tests
echo "1. Running Perl unit tests..."
prove -Ilib t/
echo "✓ Perl tests passed"
echo

# 2. Module import tests
echo "2. Testing module imports..."
perl -Ilib -e 'use ChromeDriver; print "✓ ChromeDriver\n"'
perl -Ilib -e 'use Page::Navigation; print "✓ Page::Navigation\n"'
perl -Ilib -e 'use Content::Extraction; print "✓ Content::Extraction\n"'
perl -Ilib -e 'use Visual::Capture; print "✓ Visual::Capture\n"'
perl -Ilib -e 'use Print::PDF; print "✓ Print::PDF\n"'
perl -Ilib -e 'use DOM::Elements; print "✓ DOM::Elements\n"'
perl -Ilib -e 'use JS::Execute; print "✓ JS::Execute\n"'
perl -Ilib -e 'use Session::Cookies; print "✓ Session::Cookies\n"'
perl -Ilib -e 'use Help::Browser; print "✓ Help::Browser\n"'
echo

# 3. Plugin structure
echo "3. Verifying plugin structure..."
test -f .claude-plugin/plugin.json && echo "✓ plugin.json exists"
test -f .claude-plugin/marketplace.json && echo "✓ marketplace.json exists"
test -d skills && echo "✓ skills/ directory exists"
test -d commands && echo "✓ commands/ directory exists"
test -d hooks && echo "✓ hooks/ directory exists"
test -f skills/browser-automation/SKILL.md && echo "✓ SKILL.md exists"
test -f commands/browser.md && echo "✓ browser.md exists"
test -f commands/screenshot.md && echo "✓ screenshot.md exists"
test -f commands/pdf.md && echo "✓ pdf.md exists"
test -f commands/extract.md && echo "✓ extract.md exists"
test -f hooks/hooks.json && echo "✓ hooks.json exists"
echo

# 4. Documentation
echo "4. Checking documentation..."
test -f README.md && echo "✓ README.md"
test -f TROUBLESHOOTING.md && echo "✓ TROUBLESHOOTING.md"
test -f TESTING.md && echo "✓ TESTING.md"
test -f CHANGELOG.md && echo "✓ CHANGELOG.md"
test -f LICENSE && echo "✓ LICENSE"
echo

# 5. Validate JSON files
echo "5. Validating JSON files..."
python3 -m json.tool .claude-plugin/plugin.json > /dev/null && echo "✓ plugin.json is valid"
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "✓ marketplace.json is valid"
python3 -m json.tool hooks/hooks.json > /dev/null && echo "✓ hooks.json is valid"
echo

echo "=== All tests passed! ==="
echo
echo "Next steps:"
echo "  1. Install plugin: /plugin marketplace add $(pwd)"
echo "  2. Then: /plugin install chrome-driver@chrome-driver-dev"
echo "  3. Restart Claude Code"
echo "  4. Test with: 'Take a screenshot of example.com'"
