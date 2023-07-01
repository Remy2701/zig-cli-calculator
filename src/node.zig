const std = @import("std");

pub const Node = union(enum) {
    Number: NumberNode,
    BinOp: BinOpNode,
    SymbolCall: SymbolCallNode,
    FunCall: FunCallNode,

    pub fn deinit(self: *const Node, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .BinOp => |node| node.deinit(allocator),
            .SymbolCall => |node| node.deinit(allocator),
            .FunCall => |node| node.deinit(allocator),
            else => {}
        }
    }

    pub fn format(self: Node, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .Number => |node| try node.format(fmt, options, writer),
            .BinOp => |node| try node.format(fmt, options, writer),
            .SymbolCall => |node| try node.format(fmt, options, writer),
            .FunCall => |node| try node.format(fmt, options, writer),
        }
    }

    pub fn clone(self: *const Node, allocator: std.mem.Allocator) Node {
        switch (self.*) {
            .Number => |node| return node.clone(allocator),
            .BinOp => |node| return node.clone(allocator),
            .SymbolCall => |node| return node.clone(allocator),
            .FunCall => |node| return node.clone(allocator),
        }
    }

    pub fn cloneSpe(self: *const Node, allocator: std.mem.Allocator, spe: std.ArrayList([]const u8)) Node {
        switch (self.*) {
            .Number => |node| return node.cloneSpe(allocator, spe),
            .BinOp => |node| return node.cloneSpe(allocator, spe),
            .SymbolCall => |node| return node.cloneSpe(allocator, spe),
            .FunCall => |node| return node.cloneSpe(allocator, spe),
        }
    }
};

pub const NumberNode = struct {
    value: f64,

    pub fn format(self: NumberNode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try std.fmt.format(writer, "{d}", .{self.value});
    }

    pub fn clone(self: *const NumberNode, allocator: std.mem.Allocator) Node {
        _ = allocator;
        return Node {
            .Number = NumberNode {
                .value = self.value
            }
        };
    }

    pub fn cloneSpe(self: *const NumberNode, allocator: std.mem.Allocator, spe: std.ArrayList([]const u8)) Node {
        _ = spe;
        _ = allocator;
        return Node {
            .Number = NumberNode {
                .value = self.value
            }
        };
    }
};

pub const SymbolCallNode = struct {
    value: []const u8,

    pub fn format(self: SymbolCallNode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try std.fmt.format(writer, "{s}", .{self.value});
    }

    pub fn clone(self: *const SymbolCallNode, allocator: std.mem.Allocator) Node {
        return Node {
            .SymbolCall = SymbolCallNode {
                .value = allocator.dupe(u8, self.value) catch unreachable
            }
        };
    }

    pub fn cloneSpe(self: *const SymbolCallNode, allocator: std.mem.Allocator, spe: std.ArrayList([]const u8)) Node {
        for (spe.items) |item| {
            if (std.mem.eql(u8, item, self.value)) {
                return Node {
                    .SymbolCall = SymbolCallNode {
                        .value = std.mem.concat(allocator, u8, &[_][]const u8 {"$", self.value}) catch unreachable
                    }
                };
            }
        }

        return Node {
            .SymbolCall = SymbolCallNode {
                .value = allocator.dupe(u8, self.value) catch unreachable
            }
        };
    }

    pub fn deinit(self: *const SymbolCallNode, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
    }
};

pub const FunCallNode = struct {
    value: []const u8,
    parameters: std.ArrayList(Node),

    pub fn format(self: FunCallNode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try std.fmt.format(writer, "{s}(", .{self.value});
        var i: usize = 0;
        for (self.parameters.items) |param| {
            if (i != 0) try writer.writeAll(", ");
            try std.fmt.format(writer, "{}", .{param});
            i += 1;
        }
        try writer.writeAll(")");
    }

    pub fn clone(self: *const FunCallNode, allocator: std.mem.Allocator) Node {
        var parameters = std.ArrayList(Node).initCapacity(allocator, self.parameters.items.len) catch unreachable;
        for (self.parameters.items) |item| {
            parameters.append(item.clone(allocator)) catch unreachable;
        }
        return Node {
            .FunCall = FunCallNode {
                .value = allocator.dupe(u8, self.value) catch unreachable,
                .parameters = parameters
            }
        };
    }

    pub fn cloneSpe(self: *const FunCallNode, allocator: std.mem.Allocator, spe: std.ArrayList([]const u8)) Node {
        var parameters = std.ArrayList(Node).initCapacity(allocator, self.parameters.items.len) catch unreachable;
        for (self.parameters.items) |item| {
            parameters.append(item.cloneSpe(allocator, spe)) catch unreachable;
        }
        return Node {
            .FunCall = FunCallNode {
                .value = allocator.dupe(u8, self.value) catch unreachable,
                .parameters = parameters
            }
        };
    }

    pub fn deinit(self: *const FunCallNode, allocator: std.mem.Allocator) void {
        allocator.free(self.value);

        for (self.parameters.items) |item| {
            item.deinit(allocator);
        }
        self.parameters.deinit();
    }
};

pub const BinOpNode = struct {
    pub const Operator = enum {
        Add,
        Sub,
        Mul,
        Div,
        Assign,

        pub fn format(self: Operator, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = options;
            _ = fmt;
            switch (self) {
                .Add => try writer.writeAll("+"),
                .Sub => try writer.writeAll("-"),
                .Mul => try writer.writeAll("*"),
                .Div => try writer.writeAll("/"),
                .Assign => try writer.writeAll("="),
            }
        }
    };
    
    lhs: *Node,
    op: Operator,
    rhs: *Node,

    pub fn deinit(self: *const BinOpNode, allocator: std.mem.Allocator) void {
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        allocator.destroy(self.lhs);
        allocator.destroy(self.rhs);
    }

    pub fn clone(self: *const BinOpNode, allocator: std.mem.Allocator) Node {
        var lhs = allocator.create(Node) catch unreachable;
        lhs.* = self.lhs.clone(allocator);
        var rhs = allocator.create(Node) catch unreachable;
        rhs.* = self.rhs.clone(allocator);
        return Node {
            .BinOp = BinOpNode {
                .lhs = lhs,
                .op = self.op,
                .rhs = rhs
            }
        };
    }

    pub fn cloneSpe(self: *const BinOpNode, allocator: std.mem.Allocator, spe: std.ArrayList([]const u8)) Node {
        var lhs = allocator.create(Node) catch unreachable;
        lhs.* = self.lhs.cloneSpe(allocator, spe);
        var rhs = allocator.create(Node) catch unreachable;
        rhs.* = self.rhs.cloneSpe(allocator, spe);
        return Node {
            .BinOp = BinOpNode {
                .lhs = lhs,
                .op = self.op,
                .rhs = rhs
            }
        };
    }

    pub fn format(self: BinOpNode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;
        try std.fmt.format(writer, "({} {} {})", .{self.lhs, self.op, self.rhs});
    }
};