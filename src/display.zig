usingnamespace @import("c.zig");

/// Options for the display such as width, height and title
pub const Options = struct {
    /// Sets the initial window width
    width: c_int,
    /// Sets the initial window height
    height: c_int,
    /// Sets the title of the window
    title: [*c]const u8,
};

/// Creates a new window, can fail initialization
/// Currently uses opengl version 3.3 for most compatibility
pub fn init(
    /// The options to set the window
    options: Options,
    /// Callback function that should provide the texture to be rendered on frame updates
    getTexture: fn () [][][3]u8,
) !void {
    if (glfwInit() == 0) {
        return error.FailedToInitialize;
    }

    // using opengl 3.3 we support pretty much anything
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_RESIZABLE, 0);

    var window = glfwCreateWindow(options.width, options.height, options.title, null, null);
    glfwMakeContextCurrent(window);

    while (glfwWindowShouldClose(window) == 0) {
        var w: c_int = 0;
        var h: c_int = 0;
        glfwGetFramebufferSize(window, &w, &h);
        glViewport(0, 0, w, h);

        glClear(GL_COLOR_BUFFER_BIT);
        glClearColor(0, 1, 0, 0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    glfwDestroyWindow(window);
}
