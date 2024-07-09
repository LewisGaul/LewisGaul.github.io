const std = @import("std");
const zine = @import("zine");

pub fn build(b: *std.Build) !void {
    try zine.addWebsite(b, .{
        .title = "Lewis Gaul",
        .host_url = "https://lewisgaul.co.uk",
        .layouts_dir_path = "layouts",
        .content_dir_path = "content",
        .static_dir_path = "static",
    });
}
