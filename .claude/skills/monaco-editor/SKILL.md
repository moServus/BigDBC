# Skill: monaco-editor

Covers the Monaco Editor integration in `MonacoSqlEditor.razor` and `wwwroot/js/monaco-interop.js`.

## Initialization

Monaco is loaded via CDN (or bundled). The editor instance is created in JS and a .NET object reference is passed to it for callbacks:

```js
// monaco-interop.js
export function initEditor(elementId, dotnetRef, language) {
    const editor = monaco.editor.create(document.getElementById(elementId), {
        language: language,
        automaticLayout: true,
    });
    editor.onDidChangeModelContent(() => {
        dotnetRef.invokeMethodAsync('OnContentChanged', editor.getValue());
    });
    window._monacoEditors = window._monacoEditors || {};
    window._monacoEditors[elementId] = editor;
}

export function getValue(elementId) {
    return window._monacoEditors[elementId]?.getValue() ?? '';
}

export function setValue(elementId, value) {
    window._monacoEditors[elementId]?.setValue(value);
}
```

In the Razor component, call `initEditor` from `OnAfterRenderAsync(firstRender: true)`.

## Per-Connector Language Mode

Each connector declares its query language in `ConnectorMetadata.QueryLanguage` (e.g., `"sql"`, `"json"`). Pass this to `initEditor` as the `language` parameter so Monaco applies the right syntax highlighting.

## Schema-Driven Autocomplete

After loading schema via `GetSchemaAsync`, push table/column names into Monaco's completion provider:

```js
export function registerCompletions(language, tables) {
    monaco.languages.registerCompletionItemProvider(language, {
        provideCompletionItems: () => ({
            suggestions: tables.flatMap(t => [
                { label: t.name, kind: monaco.languages.CompletionItemKind.Class, insertText: t.name },
                ...t.columns.map(c => ({
                    label: c, kind: monaco.languages.CompletionItemKind.Field, insertText: c
                }))
            ])
        })
    });
}
```

Call `registerCompletions` from Blazor after `GetSchemaAsync` resolves, passing the serialized table list via JS interop.

## Key Bindings

Run query on `Ctrl+Enter` / `Cmd+Enter`:

```js
editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter, () => {
    dotnetRef.invokeMethodAsync('OnRunQuery');
});
```
