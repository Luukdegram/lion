const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("lion", "src/main.zig");
    exe.addCSourceFile("thirdparty/dr_wav.c", &[_][]const u8{"-std=c99"});
    exe.addIncludeDir("thirdparty");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("openal");
    exe.linkSystemLibrary("glfw");
    exe.linkLibC();
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.addArg("assets/roms/test_opcode.ch8");
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the test rom");
    run_step.dependOn(&run_cmd.step);
}
