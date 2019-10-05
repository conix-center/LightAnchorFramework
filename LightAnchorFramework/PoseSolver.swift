//
//  LocationSolver.swift
//  LASwift
//
//  Created by Nick Wilkerson on 6/13/19.
//

import Foundation//UIKit
import Accelerate
import ARKit /* uses arkit for the variable types doesn't use arkit functions */
import LASwift


struct AnchorPoint {
    var location3d: SCNVector3
    var location2d: CGPoint
}

class PoseSolver: NSObject {
    
    func solveForPose(intrinsics: simd_double3x3, cameraTransform: simd_double4x4, anchorPoints:[AnchorPoint], callback: @escaping ((simd_double4x4, Bool)->()))  {
        
        DispatchQueue.global(qos: .default).async {
            
            NSLog("points")
            for point in anchorPoints {
                NSLog("x: \(point.location2d.x), y: \(point.location2d.y)")
            }
            
            NSLog("intrinsics")
            self.printMatrix(intrinsics)
            
            NSLog("extrinsics")
            self.printMatrix(cameraTransform)
            
            let worldTransform = cameraTransform.inverse
            let correctedIntrinsics = self.convert(matrix: intrinsics) * worldTransform
            
            let numPoints = anchorPoints.count
            
            //var fixedCoords = Array(repeating: Array(repeating: 1, count: anchorPoints.count), count: 4)
            //   var fixedCoords = [simd_double4]()
            //            for i in 0..<numPoints {
            //                let point = anchorPoints[i]
            //                let spoint = simd_double4(x: Double(point.location3d.x), y: Double(point.location3d.y), z: Double(point.location3d.z), w: 1.0)
            //            //    fixedCoords.append( worldTransform * spoint )
            //            }
            
            let k11 = correctedIntrinsics[0][0]
            let k12 = correctedIntrinsics[1][0]
            let k13 = correctedIntrinsics[2][0]
            let k14 = correctedIntrinsics[3][0]
            let k21 = correctedIntrinsics[0][1]
            let k22 = correctedIntrinsics[1][1]
            let k23 = correctedIntrinsics[2][1]
            let k24 = correctedIntrinsics[3][1]
            let k31 = correctedIntrinsics[0][2]
            let k32 = correctedIntrinsics[1][2]
            let k33 = correctedIntrinsics[2][2]
            let k34 = correctedIntrinsics[3][2]
            
            let matrixA = Matrix(numPoints*2, 5)
            var vectorB = Vector(repeating: 0.0, count: numPoints * 2)
            for i in 0..<numPoints {
                let u = Double(anchorPoints[i].location2d.x)
                let v = Double(anchorPoints[i].location2d.y)
                let x = Double(anchorPoints[i].location3d.x)//fixedCoords[i][0]
                let y = Double(anchorPoints[i].location3d.y)//fixedCoords[i][1]
                let z = Double(anchorPoints[i].location3d.z)//fixedCoords[i][2]
                let first1 = (u*k31-k11)*x
                let second1 = (u*k33-k13)*z
                
                matrixA[i*2,0] = Double(first1+second1)
                let first2 = (u*k31-k11)*z
                let second2 = (u*k33-k13)*x
                matrixA[i*2,1] = Double(first2-second2)
                matrixA[i*2,2] = Double(u*k31-k11)
                matrixA[i*2,3] = Double(u*k32-k12)
                matrixA[i*2,4] = Double(u*k33-k13)
                
                let first3 = (v*k31-k21)*x
                let second3 = (v*k33-k23)*z
                matrixA[i*2+1,0] = Double(first3+second3)
                let first4 = (v*k31-k21)*z
                let second4 = (v*k33-k23)*x
                matrixA[i*2+1,1] = Double(first4-second4)
                matrixA[i*2+1,2] = Double(v*k31-k21)
                matrixA[i*2+1,3] = Double(v*k32-k22)
                matrixA[i*2+1,4] = Double(v*k33-k23)
                
                vectorB[i*2] = Double(k12-u*k32)*Double(y)+k14-u*k34
                vectorB[i*2+1] = Double(k22-v*k32)*Double(y)+k24-v*k34
            }
            
            let (xStar, success) = self.solveQP(matrixA: matrixA, vectorB: vectorB)
            var newTransform = simd_double4x4()
            newTransform[0][0] = Double(xStar[0])
            newTransform[2][0] = Double(xStar[1])
            newTransform[3][0] = Double(xStar[2])
            newTransform[1][1] = Double(1)
            newTransform[3][1] = Double(xStar[3])
            newTransform[0][2] = Double(-xStar[1])
            newTransform[2][2] = Double(xStar[0])
            newTransform[3][2] = Double(xStar[4])
            newTransform[3][3] = Double(1)
            
            DispatchQueue.main.async {
                callback(newTransform, success)
            }
        }
    }
    
    
    func solveQP(matrixA: Matrix, vectorB: Vector) -> (Vector, Bool) {
        
        let matrixC: Matrix = Matrix([[1.0, 0.0, 0.0, 0.0, 0.0],
                                      [0.0, 1.0, 0.0, 0.0, 0.0]])
        
        var (matrixU, _, _, alpha, gamma, success) = gsvd(matrixA, matrixC)
        if success == false || alpha.count != 2 {
            return (Vector(), false)
        }
        alpha.reverse()
        gamma.reverse()
        
        let mu = alpha .* alpha ./ (gamma .* gamma)
        let matrixU2 = Matrix([matrixU[col: 4], matrixU[col: 3]])
        
        let c = (matrixU2 * Matrix(vectorB)).flat
        var f = alpha .* alpha .* gamma .* gamma .* c .* c
        f.append(-1)
        
        let gammaZero2 = gamma[0] * gamma[0]
        let gammaZero4 = gammaZero2 * gammaZero2
        let gammaOne2 = gamma[1] * gamma[1]
        let gammaOne4 = gammaOne2 * gammaOne2
        let alphaZero2 = alpha[0] * alpha[0]
        let alphaZero4 = alphaZero2 * alphaZero2
        let alphaOne2 = alpha[1] * alpha[1]
        let alphaOne4 = alphaOne2 * alphaOne2
        var poly: [Double] = [
            f[2]*gammaZero4*gammaOne4,
            2*f[2]*gammaZero4*gammaOne2*alphaOne2+2*f[2]*gammaZero2*gammaOne4*alphaZero2,
            f[2]*gammaZero4*alphaOne4+4*f[2]*gammaZero2*gammaOne2*alphaZero2*alphaOne2+f[2]*gammaOne4*alphaZero4+f[0]*gammaOne4+f[1]*gammaZero4,
            2*f[2]*gammaZero2*alphaZero2*alphaOne4+2*f[2]*gammaOne2*alphaZero4*alphaOne2+2*f[0]*gammaOne2*alphaOne2+2*f[1]*gammaZero2*alphaZero2,
            f[2]*alphaZero4*alphaOne4+f[0]*alphaOne4+f[1]*alphaZero4]
        var roots = Array(repeating: 0.0, count: 4)
        poly.reverse()
        solve_real_poly(4, &poly, &roots)
        
        //        NSLog("roots[0]: \(roots[0])")
        //        NSLog("roots[1]: \(roots[1])")
        //        NSLog("roots[2]: \(roots[2])")
        //        NSLog("roots[3]: \(roots[3])")
        var maximum = -Double.greatestFiniteMagnitude
        //        NSLog("maximum: \(maximum)")
        for val in roots {
            if !val.isNaN && val > maximum {
                maximum = val
            }
        }
        let lambdaStar = maximum
        //        NSLog("lambdaStar: \(lambdaStar)")
        let muStar = min(mu)
        if lambdaStar <= -muStar + 1e-15 {
            return (Vector(), false)
        }
        let invMat = inv((matrixA′ * matrixA) + lambdaStar .* (matrixC′ * matrixC))
        let rhsMat = (matrixA′ * Matrix(vectorB))
        let xStar = invMat * rhsMat
        //        NSLog("xstar[0]: \(xStar.flat[0])")
        //        NSLog("xstar[1]: \(xStar.flat[1])")
        //        NSLog("xstar[2]: \(xStar.flat[2])")
        //        NSLog("xstar[3]: \(xStar.flat[3])")
        //        NSLog("xstar[4]: \(xStar.flat[4])")
        return (xStar.flat, true)
    }
    
    
    /// Perform a generalized singular value decomposition of 2 given matrices.
    ///
    /// - Parameters:
    ///    - A: first matrix
    ///    - B: second matrix
    /// - Returns: matrices U, V, and Q, plus vectors alpha and beta
    public func gsvd(_ A: Matrix, _ B: Matrix) -> (U: Matrix, V: Matrix, Q: Matrix, alpha: Vector, beta: Vector, success: Bool) {
        /* LAPACK is using column-major order */
        let _A = toCols(A, .Row)
        let _B = toCols(B, .Row)
        
        var jobu:Int8 = Int8(Array("U".utf8).first!)
        var jobv:Int8 = Int8(Array("V".utf8).first!)
        var jobq:Int8 = Int8(Array("Q".utf8).first!)
        
        var M = __CLPK_integer(A.rows)
        var N = __CLPK_integer(A.cols)
        var P = __CLPK_integer(B.rows)
        
        var LDA = M
        var LDB = P
        var LDU = M
        var LDV = P
        var LDQ = N
        
        let lWork = max(max(Int(3*N),Int(M)),Int(P))+Int(N)
        var iWork = [__CLPK_integer](repeating: 0, count: Int(N))
        var work = Vector(repeating: 0.0, count: Int(lWork) * 4)
        var error = __CLPK_integer(0)
        
        var k = __CLPK_integer()
        var l = __CLPK_integer()
        
        let U = Matrix(Int(LDU), Int(M))
        let V = Matrix(Int(LDV), Int(P))
        let Q = Matrix(Int(LDQ), Int(N))
        var alpha = Vector(repeating: 0.0, count: Int(N))
        var beta = Vector(repeating: 0.0, count: Int(N))
        
        dggsvd_(&jobu, &jobv, &jobq, &M, &N, &P, &k, &l, &_A.flat, &LDA, &_B.flat, &LDB, &alpha, &beta, &U.flat, &LDU, &V.flat, &LDV, &Q.flat, &LDQ, &work, &iWork, &error)
        
        //precondition(error == 0, "Failed to compute SVD")
        if error != 0 {
            return (toRows(U, .Column), toRows(V, .Column), toRows(Q, .Column), Vector(alpha[Int(k)...Int(k+l)-1]), Vector(beta[Int(k)...Int(k+l)-1]), false)
        } else {
            return (toRows(U, .Column), toRows(V, .Column), toRows(Q, .Column), Vector(alpha[Int(k)...Int(k+l)-1]), Vector(beta[Int(k)...Int(k+l)-1]), true)
        }
    }
    
    /*
     convert: makes sure all the coordinate systems have the same handedness
     */
    func convert(matrix: simd_double3x3) -> simd_double4x4 {
        var outMatrix = simd_double4x4()
        outMatrix.columns.0.x = matrix.columns.0.x
        outMatrix.columns.0.y = matrix.columns.0.y
        outMatrix.columns.0.z = matrix.columns.0.z
        outMatrix.columns.1.x = -matrix.columns.1.x
        outMatrix.columns.1.y = -matrix.columns.1.y
        outMatrix.columns.1.z = -matrix.columns.1.z
        outMatrix.columns.2.x = -matrix.columns.2.x
        outMatrix.columns.2.y = -matrix.columns.2.y
        outMatrix.columns.2.z = -matrix.columns.2.z
        outMatrix.columns.3.w = 1
        return outMatrix
    }
    
    func printMatrix(_ m: simd_double4x4) {
        for i in 0..<4 {
            print(String(m.columns.0[i]) + "\t\t" + String(m.columns.1[i]) + "\t\t" + String(m.columns.2[i]) + "\t\t" + String(m.columns.3[i]))
        }
    }
    
    func printMatrix(_ m: simd_double3x3) {
        for i in 0..<3 {
            print(String(m.columns.0[i]) + "\t\t" + String(m.columns.1[i]) + "\t\t" + String(m.columns.2[i]))
        }
    }
    
    func printMatrix(_ m: [simd_double4]) {
        for r in m {
            print(String(r[0]) + "\t\t" + String(r[1]) + "\t\t" + String(r[2]) + "\t\t" + String(r[3]))
        }
    }
    
    func printMatrix(_ m: Matrix) {
        for r in 0..<m.rows {
            for c in 0..<m.cols {
                print(String(m[r,c]) + "\t\t", terminator: "")
            }
            print()
        }
    }
    
    
}


