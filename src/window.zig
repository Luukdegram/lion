usingnamespace @import("c.zig");
const Texture = @import("texture.zig").Texture;

/// Options for the display such as width, height and title
pub const Options = struct {
    /// Sets the initial window width
    width: c_int,
    /// Sets the initial window height
    height: c_int,
    /// Sets the title of the window
    title: [*c]const u8,
};

/// our window
var window: *GLFWwindow = undefined;

/// the texture to render each frame
var texture: Texture = undefined;

/// Creates a new window, can fail initialization
/// Currently uses opengl version 3.3 for most compatibility
pub fn init(options: Options, comptime callback: var) !void {
    if (glfwInit() == 0) {
        return error.FailedToInitialize;
    }

    errdefer glfwTerminate();

    // using opengl 3.3 we support pretty much anything
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

    window = glfwCreateWindow(options.width, options.height, options.title, null, null) orelse return error.WindowCreationFailed;
    glfwMakeContextCurrent(window);
    errdefer glfwDestroyWindow(window);

    _ = glfwSetKeyCallback(window, callback);

    texture = try Texture.init();

    glClearColor(0.2, 0.3, 0.3, 1);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

/// Updates the frame once based on the given frame
/// Make sure init() is called before using update
pub fn update(frame: []u1) void {
    var w: c_int = 0;
    var h: c_int = 0;
    glfwGetFramebufferSize(window, &w, &h);
    glViewport(0, 0, w, h);
    glClear(GL_COLOR_BUFFER_BIT);

    texture.draw(frame);

    glfwSwapBuffers(window);
    glfwPollEvents();
}

/// Destroys Opengl buffers and the window
pub fn deinit() void {
    texture.deinit();
    glfwDestroyWindow(window);
}

/// Shuts down the GLFW window
pub fn shutdown() void {
    glfwSetWindowShouldClose(window, GL_TRUE);
}
