const std = @import("std");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");
const Interpreter = @import("Interpreter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .stack_trace_frames = 5
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    const MAX_SIZE = 1024;

    var interpreter = Interpreter.init(allocator);
    defer interpreter.deinit();

    while (true) {
        stdout.writeAll(">> ") catch unreachable;
        const buffer = stdin.readUntilDelimiterAlloc(allocator, '\n', MAX_SIZE) catch unreachable;
        defer allocator.free(buffer);

        if (std.mem.eql(u8, buffer, "exit") or std.mem.eql(u8, buffer, "stop")) break;

        var lexer = Lexer.init(allocator, buffer);
        const tokens = lexer.tokenize();
        defer {
            for (tokens.items) |token| {
                token.deinit(allocator);
            }
            tokens.deinit();
        }

        var parser = Parser.init(allocator, tokens);
        const node = parser.parse();
        defer {
            node.deinit(allocator);
        }

        if (interpreter.interpret(node)) |value| {
            std.debug.print("{d}\n", .{value});
        }
    }
}