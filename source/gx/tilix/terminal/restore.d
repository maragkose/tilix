/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.terminal.restore;

import core.sys.posix.unistd;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.format;
import std.path;
import std.regex;
import std.string;

/**
 * Programs that are safe to start again when a session is restored. Anything
 * else, e.g. a build or a one-off script, is deliberately not re-run.
 */
immutable string[] RESTORABLE_PROGRAMS = ["ssh", "mosh", "vim", "nvim", "vi", "nano", "less", "man", "htop", "top", "btop", "watch", "tail"];

/**
 * Cursor CLI executables, restored with the chat they had open.
 */
immutable string[] AGENT_PROGRAMS = ["agent", "cursor-agent"];

/**
 * Returns the command that resumes the program leading the process group pgid,
 * or null if that program should not be restored.
 */
string getRestoreCommand(pid_t pgid) {
    string[] argv = readCmdline(pgid);
    if (argv.length == 0) return null;
    return buildRestoreCommand(argv, readFdTargets(pgid));
}

/**
 * Builds the restore command from a process command line and the targets of
 * its open file descriptors.
 */
string buildRestoreCommand(string[] argv, string[] fdTargets) {
    string program = baseName(argv[0]);
    if (AGENT_PROGRAMS.canFind(program)) {
        string chatId = findAgentChatId(fdTargets);
        return chatId.length > 0 ? format("%s --resume %s", program, chatId) : program;
    }
    if (RESTORABLE_PROGRAMS.canFind(program)) {
        return (program ~ argv[1..$]).map!(quoteArgument).join(" ");
    }
    return null;
}

private:

/**
 * The agent keeps its chat database open at ~/.cursor/chats/<project>/<chat id>/store.db
 */
string findAgentChatId(string[] fdTargets) {
    auto chatStore = ctRegex!(`/\.cursor/chats/[^/]+/([0-9a-f-]{36})/store\.db$`);
    foreach (target; fdTargets) {
        auto m = matchFirst(target, chatStore);
        if (!m.empty) return m[1];
    }
    return null;
}

string quoteArgument(string arg) {
    auto plain = ctRegex!(`^[A-Za-z0-9_@%+=:,./-]+$`);
    if (!matchFirst(arg, plain).empty) return arg;
    return "'" ~ arg.replace("'", `'\''`) ~ "'";
}

string[] readCmdline(pid_t pid) {
    try {
        string data = to!string(cast(char[]) read(format("/proc/%d/cmdline", pid)));
        return data.split('\0').filter!(a => a.length > 0).array;
    } catch (FileException) {
        return [];
    }
}

string[] readFdTargets(pid_t pid) {
    string[] result;
    try {
        foreach (entry; dirEntries(format("/proc/%d/fd", pid), SpanMode.shallow, false)) {
            try {
                result ~= readLink(entry.name);
            } catch (FileException) {
                // fd closed while iterating
            }
        }
    } catch (FileException) {
        return [];
    }
    return result;
}

unittest {
    string[] agentFds = ["/dev/pts/7", "/home/me/.cursor/chats/5b60bbffea03e8c8baf0c90c9a5c027f/d1daabb9-9063-4cd0-8d32-246d813584cd/store.db"];
    string[] agentArgv = ["/home/me/.local/bin/agent", "--use-system-ca", "/home/me/.local/share/cursor-agent/index.js", "--resume"];
    assert(buildRestoreCommand(agentArgv, agentFds) == "agent --resume d1daabb9-9063-4cd0-8d32-246d813584cd");
    assert(buildRestoreCommand(agentArgv, ["/dev/pts/7"]) == "agent");
    assert(buildRestoreCommand(["/usr/bin/vim", "my notes.txt"], []) == "vim 'my notes.txt'");
    assert(buildRestoreCommand(["ssh", "user@host", "-p", "2222"], []) == "ssh user@host -p 2222");
    assert(buildRestoreCommand(["make", "-j8"], []) is null);
    assert(quoteArgument("it's") == `'it'\''s'`);
}
