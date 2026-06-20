#pragma once
/**
 * Bantu Language v1.2.1 — Module Resolver
 *
 * Resolves `include` paths relative to the importing file, reads, lexes,
 * and parses the target `.b` file into an AST. The Evaluator is responsible
 * for executing the AST in the proper scope.
 *
 * Resolution order:
 *   1. If `path` is absolute and exists, use it directly.
 *   2. Resolve relative to the *importing* file's directory (preferred).
 *   3. Resolve relative to the current working directory.
 *   4. Try with `.b` extension appended if missing.
 *
 * The resolver never throws — on failure it returns an empty AST and
 * records a diagnostic string in `errOut`.
 */

#include "types.hpp"
#include "lexer.hpp"
#include "parser.hpp"

#include <string>
#include <vector>
#include <memory>
#include <fstream>
#include <sstream>
#include <sys/stat.h>

#ifdef _WIN32
    #include <direct.h>
    #define GETCWD _getcwd
#else
    #include <unistd.h>
    #define GETCWD getcwd
#endif

namespace bantu {

inline bool pathExists(const std::string& p) {
    struct stat buf;
    return stat(p.c_str(), &buf) == 0;
}

inline std::string dirOf(const std::string& path) {
    size_t slash = path.find_last_of("/\\");
    return (slash == std::string::npos) ? "." : path.substr(0, slash);
}

inline std::string getCwd() {
    char buf[4096];
    if (GETCWD(buf, sizeof(buf)) != nullptr) return std::string(buf);
    return ".";
}

inline std::string joinPath(const std::string& dir, const std::string& rel) {
    if (rel.empty()) return dir;
    if (rel[0] == '/' || rel[0] == '\\' ||
        (rel.size() >= 2 && rel[1] == ':')) return rel; // absolute (POSIX or Windows drive)
    if (dir.empty() || dir == ".") return rel;
    char sep =
#ifdef _WIN32
        '\\';
#else
        '/';
#endif
    if (dir.back() == '/' || dir.back() == '\\') return dir + rel;
    return dir + std::string(1, sep) + rel;
}

struct ResolvedModule {
    std::string resolvedPath;   // absolute-ish path that was opened
    std::string source;         // file contents
    std::vector<std::shared_ptr<ASTNode>> ast;
    bool ok = false;
    std::string err;
};

inline ResolvedModule resolveAndParse(const std::string& rawPath,
                                      const std::string& importingFilePath) {
    ResolvedModule out;

    std::vector<std::string> candidates;
    // 1. Absolute (already-normalized by joinPath)
    candidates.push_back(rawPath);
    // 2. Relative to importing file's directory
    if (!importingFilePath.empty()) {
        candidates.push_back(joinPath(dirOf(importingFilePath), rawPath));
    }
    // 3. Relative to cwd
    candidates.push_back(joinPath(getCwd(), rawPath));
    // 4. Append .b if missing
    {
        std::string withExt = rawPath;
        if (withExt.size() < 2 || withExt.substr(withExt.size() - 2) != ".b") {
            withExt += ".b";
            candidates.push_back(withExt);
            if (!importingFilePath.empty()) {
                candidates.push_back(joinPath(dirOf(importingFilePath), withExt));
            }
            candidates.push_back(joinPath(getCwd(), withExt));
        }
    }

    std::string chosen;
    for (const auto& c : candidates) {
        if (pathExists(c)) { chosen = c; break; }
    }

    if (chosen.empty()) {
        out.err = "Module not found: " + rawPath;
        return out;
    }

    std::ifstream f(chosen, std::ios::binary);
    if (!f.is_open()) {
        out.err = "Cannot open module: " + chosen;
        return out;
    }
    std::stringstream ss;
    ss << f.rdbuf();
    out.source = ss.str();
    out.resolvedPath = chosen;

    try {
        Lexer lex(out.source);
        auto tokens = lex.tokenize();
        Parser parser(std::move(tokens));
        out.ast = parser.parse();
        out.ok = true;
    } catch (const std::exception& e) {
        out.err = std::string("Parse error in '") + chosen + "': " + e.what();
    } catch (...) {
        out.err = std::string("Unknown parse error in '") + chosen + "'";
    }
    return out;
}

} // namespace bantu
