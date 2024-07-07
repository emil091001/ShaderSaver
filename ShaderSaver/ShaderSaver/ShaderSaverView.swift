import ScreenSaver
import AppKit
import OpenGL.GL3

class ShaderSaverView: ScreenSaverView {
    
    private var openGLView: OpenGLView?
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setupOpenGLView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOpenGLView()
    }
    
    private func setupOpenGLView() {
        // Create an instance of OpenGLView
        openGLView = OpenGLView(frame: self.bounds)
        openGLView?.autoresizingMask = [.width, .height]

        if let openGLView = openGLView {
            self.addSubview(openGLView)
        }
    }
    
    override func startAnimation() {
        super.startAnimation()
        let pixelDensity = self.window?.backingScaleFactor ?? 1.0
        openGLView?.setupScreenPixelDenisty(pixelDensity)
    }
    
    override func stopAnimation() {
        super.stopAnimation()
    }
    
    override func draw(_ rect: NSRect) {
        super.draw(rect)
        // The OpenGLView will handle its own drawing
    }
    
    override func animateOneFrame() {
        self.needsDisplay = true
    }
}
