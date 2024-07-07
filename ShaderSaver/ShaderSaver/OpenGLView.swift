import Cocoa
import OpenGL.GL3

class OpenGLView: NSOpenGLView {

    var shaderProgram: GLuint = 0
    var vao: GLuint = 0
    var displayLink: CVDisplayLink?
    var width: GLsizei = 0
    var height: GLsizei = 0
    var scaleFactor: GLfloat = 1.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initializeOpenGL()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeOpenGL()
    }

    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        initializeOpenGL()
    }

    private func initializeOpenGL() {
        let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(NSOpenGLPFAColorSize), 24,
            UInt32(NSOpenGLPFAAlphaSize), 8,
            UInt32(NSOpenGLPFADepthSize), 24,
            UInt32(NSOpenGLPFAStencilSize), 8,
            UInt32(NSOpenGLPFADoubleBuffer),
            0
        ]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: pixelFormatAttributes) else {
            fatalError("Failed to create pixel format")
        }
        self.pixelFormat = pixelFormat
        self.openGLContext = NSOpenGLContext(format: pixelFormat, share: nil)
        self.openGLContext?.makeCurrentContext()

        setupDisplayLink()
    }
    
    public func setupScreenPixelDenisty(_ pixelDesity: CGFloat) {
        self.scaleFactor = GLfloat(1.0 / pixelDesity)
        self.width = GLsizei(bounds.width * pixelDesity)
        self.height = GLsizei(bounds.height * pixelDesity)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        openGLContext?.makeCurrentContext()

        
        // Set the viewport
        let bounds = self.bounds
        
        glViewport(0, 0, self.width, self.height)

        // Clear the screen
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))

        // Set the shader program
        glUseProgram(shaderProgram)

        // Set uniforms
        glUniform1f(glGetUniformLocation(shaderProgram, "iTime"), GLfloat(CACurrentMediaTime()))
        glUniform2f(glGetUniformLocation(shaderProgram, "iResolution"), GLfloat(bounds.width), GLfloat(bounds.height))
        glUniform1f(glGetUniformLocation(shaderProgram, "scaleFactor"), self.scaleFactor)

        
        
        // Render fullscreen quad
        glBindVertexArray(vao)
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 6)
        glBindVertexArray(0)

        glUseProgram(0)
        openGLContext?.flushBuffer()
    }

    override func prepareOpenGL() {
        super.prepareOpenGL()

        // Initialize OpenGL
        glClearColor(0.0, 0.0, 0.0, 1.0)

        // Create and compile shaders
        let vertexShader = compileShader(source: vertexShaderSource, type: GLenum(GL_VERTEX_SHADER))
        let fragmentShader = compileShader(source: fragmentShaderSource, type: GLenum(GL_FRAGMENT_SHADER))

        // Create shader program
        shaderProgram = glCreateProgram()
        glAttachShader(shaderProgram, vertexShader)
        glAttachShader(shaderProgram, fragmentShader)
        glLinkProgram(shaderProgram)

        var linkStatus: GLint = 0
        glGetProgramiv(shaderProgram, GLenum(GL_LINK_STATUS), &linkStatus)
        if linkStatus == GL_FALSE {
            var infoLog = [GLchar](repeating: 0, count: 512)
            glGetProgramInfoLog(shaderProgram, 512, nil, &infoLog)
            let log = String(cString: infoLog)
            NSLog("Shader program link error: \(log)")
        }

        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)

        // Create VAO and VBO for fullscreen quad
        let vertices: [GLfloat] = [
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
            -1.0,  1.0,
             1.0, -1.0,
             1.0,  1.0
        ]

        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)

        var vbo: GLuint = 0
        glGenBuffers(1, &vbo)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.count * MemoryLayout<GLfloat>.size, vertices, GLenum(GL_STATIC_DRAW))

        glVertexAttribPointer(0, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(2 * MemoryLayout<GLfloat>.size), nil)
        glEnableVertexAttribArray(0)

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
    }

    func compileShader(source: String, type: GLenum) -> GLuint {
        let shader = glCreateShader(type)
        var sourceUTF8 = (source as NSString).utf8String
        var sourceLength = GLint(source.utf8.count)
        glShaderSource(shader, 1, &sourceUTF8, &sourceLength)
        glCompileShader(shader)

        var compileStatus: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compileStatus)
        if compileStatus == GL_FALSE {
            var infoLog = [GLchar](repeating: 0, count: 512)
            glGetShaderInfoLog(shader, 512, nil, &infoLog)
            let log = String(cString: infoLog)
            NSLog("Shader compile error: \(log)")
        }

        return shader
    }

    private func setupDisplayLink() {
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        self.displayLink = displayLink

        CVDisplayLinkSetOutputCallback(displayLink!, { (_, _, _, _, _, context) -> CVReturn in
            let view = Unmanaged<OpenGLView>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async {
                view.setNeedsDisplay(view.bounds)
            }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())

        CVDisplayLinkStart(displayLink!)
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }

    let vertexShaderSource = """
    #version 150 core
    in vec2 position;
    void main() {
        gl_Position = vec4(position, 0.0, 1.0);
    }
    """

    let fragmentShaderSource = """
    #version 150 core
    out vec4 fragColor;
    uniform float iTime;
    uniform vec2 iResolution;
    uniform float scaleFactor;

    void mainImage(out vec4 O, in vec2 F) {
        vec2 V              = iResolution.xy,
               i            = abs(F+F-V)/V.y/.9;
        float    s          = iTime * .02,
                   u        = length(i),
                     a      = 0.0,
                       l    = 0.0;
        O = vec4(0);
        for (O *= a; a<7.; a++) {
            O += pow(.034/abs(sin(u*.5 * exp(
                              sin(length(i + vec2(
                              cos(l = a*.5 * (2. +
                              cos(s*.5))),
                              sin(l))) * (
                              cos(s)*4.+5.)) - u)*8.-s-s)
               - smoothstep(0., .8, u - .8) * 8.), 1.15)
               * (1. + cos(u*6.+a*.5+s+vec4(0,1,2,0)))
               * mix(1., u, pow(abs(sin(s*.5+.65)), 1e2));
        }
    }

    void main() {
        vec4 color = vec4(0);
        mainImage(color, gl_FragCoord.xy * scaleFactor);
        fragColor = color;
    }
    """
}
