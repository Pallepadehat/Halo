//  The handwritten "hello", as a single stroke for trim animation.
//
//  From AppleHello by Michal Tynior, https://github.com/mtynior/AppleHello
//
//  MIT License
//
//  Copyright (c) 2023 Michal Tynior
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import SwiftUI

struct HelloShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * width, y: y * height) }

        path.move(to: point(0.18942, 0.64916))
        path.addCurve(to: point(0.27418, 0.51669), control1: point(0.27418, 0.51669), control2: point(0.23809, 0.59394))
        path.addCurve(to: point(0.30536, 0.34281), control1: point(0.30196, 0.45722), control2: point(0.31651, 0.37724))
        path.addCurve(to: point(0.24651, 0.67414), control1: point(0.26479, 0.21753), control2: point(0.24062, 0.67407))
        path.addCurve(to: point(0.28192, 0.5111), control1: point(0.2524, 0.6742), control2: point(0.25206, 0.54125))
        path.addCurve(to: point(0.32367, 0.53984), control1: point(0.31178, 0.48094), control2: point(0.3223, 0.52111))
        path.addCurve(to: point(0.31839, 0.6355), control1: point(0.32589, 0.57011), control2: point(0.31687, 0.61804))
        path.addCurve(to: point(0.43599, 0.55398), control1: point(0.32473, 0.70854), control2: point(0.42787, 0.63682))
        path.addCurve(to: point(0.3834, 0.61147), control1: point(0.44471, 0.46492), control2: point(0.3683, 0.46917))
        path.addCurve(to: point(0.4418, 0.66942), control1: point(0.38895, 0.66377), control2: point(0.42346, 0.67724))
        path.addCurve(to: point(0.552, 0.38575), control1: point(0.50813, 0.64115), control2: point(0.55363, 0.49671))
        path.addCurve(to: point(0.49571, 0.60864), control1: point(0.54988, 0.24203), control2: point(0.47856, 0.38729))
        path.addCurve(to: point(0.57499, 0.64351), control1: point(0.50232, 0.69393), control2: point(0.55841, 0.66619))
        path.addCurve(to: point(0.64978, 0.36314), control1: point(0.60564, 0.60157), control2: point(0.65966, 0.48059))
        path.addCurve(to: point(0.59745, 0.62607), control1: point(0.63947, 0.24062), control2: point(0.56181, 0.44249))
        path.addCurve(to: point(0.6548, 0.65717), control1: point(0.60934, 0.68733), control2: point(0.64502, 0.6666))
        path.addCurve(to: point(0.70474, 0.51817), control1: point(0.67802, 0.6348), control2: point(0.6855, 0.5536))
        path.addCurve(to: point(0.76896, 0.5601), control1: point(0.72906, 0.4734), control2: point(0.76738, 0.50686))
        path.addCurve(to: point(0.70263, 0.65105), control1: point(0.77246, 0.67742), control2: point(0.72159, 0.67749))
        path.addCurve(to: point(0.70448, 0.51817), control1: point(0.68627, 0.62823), control2: point(0.68244, 0.56022))
        path.addCurve(to: point(0.7753, 0.52099), control1: point(0.71954, 0.48942), control2: point(0.74363, 0.48871))
        path.addCurve(to: point(0.80807, 0.51063), control1: point(0.78825, 0.53419), control2: point(0.79935, 0.53183))
        return path
    }
}
