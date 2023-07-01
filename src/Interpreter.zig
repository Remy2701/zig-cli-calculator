const std = @import("std");

const _node = @import("node.zig");
const Node = _node.Node;
const BinOpNode = _node.BinOpNode;
const NumberNode = _node.NumberNode;
const SymbolCallNode = _node.SymbolCallNode;
const FunCallNode = _node.FunCallNode;

const Self = @This();

const Function = struct {
    parameters: std.ArrayList([]const u8),
    body: Node,

    pub fn deinit(self: *const Function, allocator: std.mem.Allocator) void {
        for (self.parameters.items) |param| {
            allocator.free(param);
        }
        self.parameters.deinit();
        self.body.deinit(allocator);
    }
};

allocator: std.mem.Allocator,
symbols: std.StringHashMap(f64),
functions: std.StringHashMap(Function),

pub fn init(allocator: std.mem.Allocator) Self {
    var self = Self {
        .allocator = allocator,
        .symbols = std.StringHashMap(f64).init(allocator),
        .functions = std.StringHashMap(Function).init(allocator),
    };

    self.assign("PI", std.math.pi);

    return self;
}

pub fn deinit(self: *Self) void {
    var key_iter = self.symbols.keyIterator();
    while (key_iter.next()) |key| {
        self.allocator.free(key.*);
    }

    var iter = self.functions.iterator();
    while (iter.next()) |next| {
        self.allocator.free(next.key_ptr.*);
        next.value_ptr.*.deinit(self.allocator);
    }
    self.functions.deinit();

    self.symbols.deinit();
}

fn interpretNumber(self: *Self, num: NumberNode) ?f64 {
    _ = self;
    return num.value;
}

fn assign(self: *Self, name: []const u8, value: f64) void {
    if (self.symbols.getPtr(name)) |ptr| {
        ptr.* = value;
    } else {
        const duped_id = self.allocator.dupe(u8, name) catch unreachable;
        self.symbols.put(duped_id, value) catch unreachable;
    }
}

fn interpretBinOp(self: *Self, binop: BinOpNode) ?f64 {
    if (binop.op == .Assign) {
        switch (binop.lhs.*) {
            .FunCall => |funcall| {
                var parameters = std.ArrayList([]const u8).init(self.allocator);
                for (funcall.parameters.items) |item| {
                    parameters.append(self.allocator.dupe(u8, item.SymbolCall.value) catch unreachable) catch unreachable;
                }

                const func = Function {
                    .parameters = parameters,
                    .body = binop.rhs.cloneSpe(self.allocator, parameters)
                };

                if (self.functions.getPtr(funcall.value)) |ptr| {
                    ptr.deinit(self.allocator);
                    ptr.* = func;
                } else {
                    const duped_id = self.allocator.dupe(u8, funcall.value) catch unreachable;
                    self.functions.put(duped_id, func) catch unreachable;
                }

                return null;
            },
            .SymbolCall => |symcall| {
                const rhs = self.interpretNode(binop.rhs.*).?;
                const id = symcall.value;
                self.assign(id, rhs);
                return null;
            },
            else => unreachable
        }
    } else {
        const lhs = self.interpretNode(binop.lhs.*).?;
        const rhs = self.interpretNode(binop.rhs.*).?;
        
        switch (binop.op) {
            .Add => return lhs + rhs,
            .Sub => return lhs - rhs,
            .Mul => return lhs * rhs,
            .Div => return lhs / rhs,
            else => unreachable
        }
    }
}

fn interpretSymCall(self: *Self, symcall: SymbolCallNode) ?f64 {
    return self.symbols.get(symcall.value);
}

fn interpretFunCall(self: *Self, fun: FunCallNode) ?f64 {
    if (std.mem.eql(u8, fun.value, "sin")) {
        if(fun.parameters.items.len != 1) unreachable;
        return std.math.sin(self.interpretNode(fun.parameters.items[0]).?);
    } else if (std.mem.eql(u8, fun.value, "cos")) {
        if(fun.parameters.items.len != 1) unreachable;
        return std.math.cos(self.interpretNode(fun.parameters.items[0]).?);
    } else if (std.mem.eql(u8, fun.value, "tan")) {
        if(fun.parameters.items.len != 1) unreachable;
        return std.math.tan(self.interpretNode(fun.parameters.items[0]).?);
    }

    if (self.functions.get(fun.value)) |function| {
        var i: usize = 0;
        for (function.parameters.items) |param| {
            var temp = std.mem.concat(self.allocator, u8, &[_][]const u8 {"$", param}) catch unreachable;
            defer self.allocator.free(temp);
            self.assign(temp, self.interpretNode(fun.parameters.items[i]).?);
            i += 1;
        } 

        return self.interpretNode(function.body);
    } else {
        unreachable;
    }
}

fn interpretNode(self: *Self, node: Node) ?f64 {
    switch (node) {
        .Number => |number| return self.interpretNumber(number),
        .BinOp => |binop| return self.interpretBinOp(binop),
        .SymbolCall => |symcall| return self.interpretSymCall(symcall),
        .FunCall => |funcall| return self.interpretFunCall(funcall),
    }
}

pub fn interpret(self: *Self, node: Node) ?f64 {
    const value = self.interpretNode(node);
    if (value) |ans| {
        self.assign("ans", ans);
    }
    return value;
}