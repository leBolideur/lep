const std = @import("std");

const Lexer = @import("../interpreter/lexer/lexer.zig").Lexer;
const Parser = @import("../interpreter/parser/parser.zig").Parser;
const Object = @import("../interpreter/intern/object.zig").Object;
const ast = @import("../interpreter/ast/ast.zig");

const comp_imp = @import("compiler.zig");
const Compiler = comp_imp.Compiler;
