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

const height = 32;
const width = 64;

var window: *GLFWwindow = undefined;

const vertex_shader = @embedFile("shaders/vertex.glsl");
const fragment_shader = @embedFile("shaders/fragment.glsl");

/// Our texture quad
const vertices = &[_]GLfloat{
    -1, -1, 0,
    -1, 1,  0,
    1,  1,  0,
    1,  -1, 0,
};

/// opengl buffer id's
var vao: GLuint = undefined;
var vbo: GLuint = undefined;
var program_id: GLuint = undefined;

/// Set texture to all 0's
var texture: [height * width * 3]u8 = [_]u8{50} ** width ** height ** 3;
var tex_id: GLuint = undefined;

/// Creates a new window, can fail initialization
/// Currently uses opengl version 3.3 for most compatibility
pub fn init(options: Options) !void {
    if (glfwInit() == 0) {
        return error.FailedToInitialize;
    }

    errdefer glfwTerminate();

    // using opengl 3.3 we support pretty much anything
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_DEPTH_BITS, 0);
    glfwWindowHint(GLFW_STENCIL_BITS, 8);
    glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

    window = glfwCreateWindow(options.width, options.height, options.title, null, null) orelse return error.WindowCreationFailed;
    glfwMakeContextCurrent(window);
    errdefer glfwDestroyWindow(window);

    const fragment_id = try createShader(fragment_shader, GL_FRAGMENT_SHADER);
    const vertex_id = try createShader(vertex_shader, GL_VERTEX_SHADER);

    program_id = glCreateProgram();
    glAttachShader(program_id, vertex_id);
    glAttachShader(program_id, fragment_id);
    glLinkProgram(program_id);

    var ok: c_int = undefined;
    glGetProgramiv(program_id, GL_LINK_STATUS, &ok);
    if (ok == GL_FALSE) {
        return error.ProgramLinkFailed;
    }

    glDeleteShader(vertex_id);
    glDeleteShader(fragment_id);

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, 4 * 3 * @sizeOf(GLfloat), @ptrCast(*const c_void, &vertices), GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * @sizeOf(GLfloat), null);

    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glClearColor(0.2, 0.3, 0.3, 1);

    glEnable(GL_BLEND);

    var frame = [_]u1{0};
    while (true) {
        update(&frame);
    }
}

/// Updates the frame once based on the given frame
/// Make sure init() is called before using update
pub fn update(frame: []u1) void {
    var w: c_int = 0;
    var h: c_int = 0;
    glfwGetFramebufferSize(window, &w, &h);
    glViewport(0, 0, w, h);
    glClear(GL_COLOR_BUFFER_BIT);

    // render the quad
    glUseProgram(program_id);
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);

    glfwSwapBuffers(window);
    glfwPollEvents();
}

/// Creates a new shader source
fn createShader(source: []const u8, kind: GLenum) !GLuint {
    const id = glCreateShader(kind);
    const ptr: ?[*]const u8 = source.ptr;
    const len = @intCast(GLint, source.len);

    glShaderSource(id, 1, &ptr, &len);
    glCompileShader(id);

    var ok: GLint = undefined;
    glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    if (ok != 0) return id;

    return error.ShaderCompilationFailed;
}

/// Destroys Opengl buffers and the window
fn deinit() void {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
    glfwDestroyWindow(window);
}
