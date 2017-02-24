import 'package:barback/barback.dart';
import 'package:sass/sass.dart';
import 'package:yaml/yaml.dart';

import 'dart:async';

class SourceLoaderTransformer extends Transformer {
    final BarbackSettings settings;

    String _allowedExtentions = '.dart .html .css .scss .sass .yaml';
    List<String> _styleExtentions = ['.css', '.scss', '.sass'];
    Sass sass = new Sass();

    SourceLoaderTransformer.asPlugin(this.settings) {
        if (settings.configuration.containsKey('extentions')) {
            _allowedExtentions = settings.configuration['extentions'];
        }
    }
    String get allowedExtensions => _allowedExtentions;

    Future apply(Transform transform) async {
        String ext = transform.primaryInput.id.extension;
        if (ext == '.dart') {
            await applyDart(transform);
        } else if (ext == '.html') {
            await applyHtml(transform);
        } else if (ext == '.yaml') {
            await applyYaml(transform);
        } else if (_styleExtentions.contains(ext)) {
            await applyCss(transform);
        }
    }
    Future applyYaml(Transform transform) async {
        String sourceContent = await transform.primaryInput.readAsString();
        Map sourceList = loadYaml(sourceContent)['sources'];
        List imports = [];
        List props = [];
        sourceList.forEach((String key, String value) {
            String importName = 'style';
            if (value.contains('.html')) {
                importName = "template";
            }
            value = value.replaceAll('.html', '.dart')
                         .replaceAll('.scss', '.dart')
                         .replaceAll('.sass', '.dart')
                         .replaceAll('.css', '.dart');
            imports.add("import '$value' as $key;");
            props.add('"$key": $key.$importName');
        });
        String sources = '''
            ${imports.join('\n')}
            Map sourcePack() {
                return const {
                    ${props.join(',\n')}
                };
            }
        ''';
        print(sources);
        var id = transform.primaryInput.id.changeExtension(".dart");
        transform.addOutput(new Asset.fromString(id, sources));
    }
    Future applyDart(Transform transform) async {
        String sourceContent = await transform.primaryInput.readAsString();
        RegExp importRx = new RegExp(r"package\:dapp\/converters\/");
        sourceContent = sourceContent.replaceAllMapped(importRx, (Match match) {
            return './';
        });
        var id = transform.primaryInput.id;
        transform.addOutput(new Asset.fromString(id, sourceContent));
    }
    Future applyHtml(Transform transform) async {
        String htmlContent = await transform.primaryInput.readAsString();
        RegExp imports = new RegExp(r'\<\!\-\- (import.+) \-\-\>');
        List importList = [];
        htmlContent = htmlContent.replaceAllMapped(imports, (Match match) {
            importList.add(match.group(1));
            return '';
        });
        var id = transform.primaryInput.id.changeExtension(".dart");
        String dartContent = "${importList.join('\n')}\ntemplate(Map scope) { return '''" + htmlContent + "''';}";

        transform.addOutput(new Asset.fromString(id, dartContent));
    }
    Future applyCss(Transform transform) async {
        String sassContent = await transform.primaryInput.readAsString();


        String ext = transform.primaryInput.id.extension;
        String cssContent;

        if (ext == '.css') {
            cssContent = sassContent;
        } else {
            sass.scss = ext == '.scss';
            cssContent = await sass.transform(sassContent);
        }
        var id = transform.primaryInput.id.changeExtension(".dart");
        String dartContent = "style(Map scope) { return '''" + cssContent + "''';}";
        transform.addOutput(new Asset.fromString(id, dartContent));
    }
}
