//
//  ContentView.swift
//  drawer
//
//  Created by student on 15.12.2024.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var drawnPaths: [Path] = []
    @State private var drawnColors: [Color] = []
    @State private var currentPath: Path = Path()
    @State private var chosenColor: Color = Color.black
    @State private var eraseColor: Color = Color.white
    private var currentColor: Color {
        get {
            return isDrawing ? chosenColor : eraseColor
        }
    }
    @State private var notStartedYet: Bool = true
    @State private var isDrawing: Bool = true
    @State private var lineWidth: Float = 20
    private let frameSize: CGFloat = 300
    
    var body: some View {
        VStack {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frameSize, height: frameSize)
                    .overlay(
                        ZStack {
                            ForEach(0..<drawnPaths.count, id: \.self) { idx in
                                drawnPaths[idx].stroke(
                                    drawnColors[idx],
                                    style: StrokeStyle(
                                        lineWidth: CGFloat(lineWidth)
                                        //lineCap: .round
                                    )
                                )
                            }
                            currentPath.stroke(
                                currentColor,
                                style: StrokeStyle(
                                    lineWidth: CGFloat(lineWidth)
                                    //lineCap: .round
                                )
                            )
                        }
                    )
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if notStartedYet {
                                currentPath.move(to: value.startLocation)
                                notStartedYet = false
                            }
                            currentPath.addLine(to: value.location)
                        }
                        .onEnded { _ in
                            drawnPaths.append(currentPath)
                            drawnColors.append(currentColor)
                            currentPath = Path()
                            notStartedYet = true
                        }
                    )
            }
            
            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Text("Select")
                }
                .padding()
                .onChange(of: selectedItem) { newItem in
                    Task {
                        guard let selectedItem else { return }
                        let data = try? await selectedItem.loadTransferable(type: Data.self)
                        self.imageData = data
                        drawnPaths.removeAll()
                        drawnColors.removeAll()
                    }
                }
                
                Button(action: {
                    saveImageToPhotos()
                }) {
                    Text("Save")
                }
                .padding()
                
                Toggle("", isOn: $isDrawing).labelsHidden().padding()
                ColorPicker("", selection: $chosenColor).labelsHidden().padding()
            }
        }
    }
    
    private func pathContainsPoint(path: Path, point: CGPoint) -> Bool {
        let rect = path.boundingRect
        return rect.contains(point)
    }
    
    private func calculateTransformations(uiImage: UIImage) -> (CGFloat, CGFloat, CGFloat) {
        var scale: CGFloat
        var tx: CGFloat = 0
        var ty: CGFloat = 0
        if uiImage.size.width > uiImage.size.height {
            scale = uiImage.size.width / frameSize
            ty = (uiImage.size.width - uiImage.size.height) / 2
        } else {
            scale = uiImage.size.height / frameSize
            tx = (uiImage.size.height - uiImage.size.width) / 2
        }
        return (scale, tx, ty)
    }

    private func saveImageToPhotos() {
        guard let imageData, let uiImage = UIImage(data: imageData) else { return }
        UIGraphicsBeginImageContext(uiImage.size)
        uiImage.draw(in: CGRect(origin: CGPoint.zero, size: uiImage.size))
        
        let transform = CGAffineTransformIdentity
        let (scale, tx, ty) = calculateTransformations(uiImage: uiImage)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for idx in 0..<drawnPaths.count {
            context.setLineWidth(CGFloat(lineWidth) * scale)
            context.setStrokeColor(drawnColors[idx].cgColor!)
            context.addPath(drawnPaths[idx]
                .applying(CGAffineTransformMakeScale(scale, scale))
                .applying(CGAffineTransformTranslate(transform, -tx, -ty))
                .cgPath)
            context.strokePath()
            context.drawPath(using: .fillStroke)
        }

        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else { return }
        UIGraphicsEndImageContext()
        UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
    }
}

#Preview {
    ContentView()
}
