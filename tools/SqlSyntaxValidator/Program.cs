using System.Text;
using System.Text.RegularExpressions;
using Microsoft.SqlServer.TransactSql.ScriptDom;

if (args.Length == 0)
{
    Console.Error.WriteLine("Provide at least one SQL file or directory.");
    return 2;
}

IReadOnlyList<string> files;
try
{
    files = ResolveSqlFiles(args);
}
catch (ArgumentException exception)
{
    Console.Error.WriteLine(exception.Message);
    return 2;
}

if (files.Count == 0)
{
    Console.Error.WriteLine("No SQL files were found in the supplied paths.");
    return 2;
}

var parser = new TSql160Parser(initialQuotedIdentifiers: true);
var errorCount = 0;
var batchCount = 0;
var utf8 = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);

foreach (var file in files)
{
    string content;
    try
    {
        content = File.ReadAllText(file, utf8);
    }
    catch (DecoderFallbackException)
    {
        ReportError(file, 0, 0, 0, "The file is not valid UTF-8.");
        errorCount++;
        continue;
    }

    foreach (var batch in SplitBatches(content))
    {
        if (IsEmptyOrCommentOnly(batch.Content))
        {
            continue;
        }

        batchCount++;
        using var reader = new StringReader(batch.Content);
        parser.Parse(reader, out IList<ParseError> errors);

        foreach (var error in errors)
        {
            var fileLine = batch.StartLine + error.Line - 1;
            ReportError(file, batch.Number, fileLine, error.Column, $"SQL parser error {error.Number}.");
            errorCount++;
        }
    }
}

if (errorCount > 0)
{
    Console.Error.WriteLine($"SQL syntax validation failed. Files: {files.Count}; batches: {batchCount}; errors: {errorCount}.");
    return 1;
}

Console.WriteLine($"SQL syntax validation passed. Files: {files.Count}; batches: {batchCount}; errors: 0.");
return 0;

static IReadOnlyList<string> ResolveSqlFiles(IEnumerable<string> paths)
{
    var files = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    foreach (var path in paths)
    {
        var fullPath = Path.GetFullPath(path);
        if (File.Exists(fullPath))
        {
            if (string.Equals(Path.GetExtension(fullPath), ".sql", StringComparison.OrdinalIgnoreCase))
            {
                files.Add(fullPath);
            }

            continue;
        }

        if (Directory.Exists(fullPath))
        {
            foreach (var file in Directory.EnumerateFiles(fullPath, "*.sql", SearchOption.AllDirectories))
            {
                files.Add(Path.GetFullPath(file));
            }

            continue;
        }

        throw new ArgumentException($"Path not found: {path}");
    }

    return files.OrderBy(path => path, StringComparer.OrdinalIgnoreCase).ToArray();
}

static IEnumerable<SqlBatch> SplitBatches(string content)
{
    var lines = Regex.Split(content, "\r\n|\n|\r");
    var builder = new StringBuilder();
    var batchNumber = 1;
    var startLine = 1;

    for (var index = 0; index < lines.Length; index++)
    {
        if (Regex.IsMatch(lines[index], "^\\s*GO\\s*$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant))
        {
            yield return new SqlBatch(batchNumber, startLine, builder.ToString());
            builder.Clear();
            batchNumber++;
            startLine = index + 2;
            continue;
        }

        builder.AppendLine(lines[index]);
    }

    yield return new SqlBatch(batchNumber, startLine, builder.ToString());
}

static bool IsEmptyOrCommentOnly(string content)
{
    var withoutComments = Regex.Replace(
        content,
        @"--[^\r\n]*|/\*.*?\*/",
        string.Empty,
        RegexOptions.Singleline | RegexOptions.CultureInvariant);
    return string.IsNullOrWhiteSpace(withoutComments);
}

static void ReportError(string file, int batch, int line, int column, string message)
{
    Console.Error.WriteLine($"{file} | batch {batch} | line {line} | column {column} | {message}");
}

internal sealed record SqlBatch(int Number, int StartLine, string Content);
