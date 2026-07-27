import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # We match: ScaffoldMessenger.of(context).showSnackBar( ... SnackBar(content: Text('...')) ... );
    # Or variations
    # Since Dart is multiline, we can use a more robust regex with re.DOTALL, but let's just do a greedy match
    # up to the end of the statement.
    # Actually, a simpler way is to find ScaffoldMessenger.of(context).showSnackBar
    # and replace the whole block up to the semicolon.
    
    # Let's match ScaffoldMessenger...showSnackBar(\s*(?:const\s+)?SnackBar\(\s*content\:\s*(?:const\s+)?Text\((.*?)\)\s*(?:,[^)]*)?\)\s*\);?
    pattern = r'ScaffoldMessenger\.of\([^)]+\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(\s*content\:\s*(?:const\s+)?Text\((.*?)\)\s*(?:,[^)]*)?\)\s*\);?'
    
    def replacer(match):
        text_content = match.group(1).strip()
        is_error = 'error' in text_content.lower() or 'failed' in text_content.lower() or 'not exist' in text_content.lower() or 'invalid' in text_content.lower()
        
        type_str = 'SnackBarType.error' if is_error else 'SnackBarType.info'
        if 'success' in text_content.lower():
            type_str = 'SnackBarType.success'
            
        return f'CustomSnackBar.show(context, message: {text_content}, type: {type_str});'

    new_content = re.sub(pattern, replacer, content, flags=re.DOTALL)
    
    if new_content != content:
        if 'custom_snackbar.dart' not in new_content:
            import_statement = "import 'package:gourmet_go/widgets/custom_snackbar.dart';"
            lines = new_content.split('\n')
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    lines.insert(i, import_statement)
                    break
            new_content = '\n'.join(lines)
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Updated {filepath}')

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
