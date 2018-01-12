//
//  UIKit.swift
//  sdl2testapinotes
//
//  Created by Geordie Jay on 11.05.17.
//  Copyright © 2017 Geordie Jay. All rights reserved.
//

import JNI
import SDL
import SDL_gpu
import CoreFoundation
import struct Foundation.Date
import class Foundation.Thread

private let maxFrameRenderTimeInSeconds = 1.0 / 60.0

final public class SDL { // Only public for rootView!
    public private(set) static var rootView = UIWindow()
    static var window: Window!

    fileprivate static var shouldQuit = false

    public static func initialize() {
        self.shouldQuit = false
        self.firstRender = true
        self.rootView = UIWindow()
        self.window = nil // triggers Window deinit to destroy previous Window

        let windowOptions: SDLWindowFlags

        #if os(Android)
            // height/width are determined by the window when fullscreen:
            let SCREEN_WIDTH = 0
            let SCREEN_HEIGHT = 0

            windowOptions = [SDL_WINDOW_FULLSCREEN]
        #else
            // This corresponds to the Samsung S7 screen at its 1080p 1.5x Retina resolution:
            let SCREEN_WIDTH = 2560 / 3
            let SCREEN_HEIGHT = 1440 / 3
            windowOptions = [
                SDL_WINDOW_ALLOW_HIGHDPI,
                //SDL_WINDOW_FULLSCREEN
            ]
        #endif

        SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "best")

        let window = Window(size: CGSize(width: SCREEN_WIDTH, height: SCREEN_HEIGHT), options: windowOptions)

        if window.size == .zero {
            preconditionFailure("You need window dimensions to run")
        }

        rootView.frame.size = window.size

        self.window = window
        UIFont.loadSystemFonts() // should always happen on UIKit-SDL init
    }

    private static var onUnloadListeners: [() -> Void] = []
    public static func onUnload(_ callback: @escaping () -> Void) {
        onUnloadListeners.append(callback)
    }

    private static func unload() {
        onUnloadListeners.forEach { $0() }
        onUnloadListeners.removeAll()
        DisplayLink.activeDisplayLinks.removeAll()
        UIView.layersWithAnimations.removeAll()
        UITouch.activeTouches.removeAll()
        UIView.currentAnimationPrototype = nil
    }

    private static var firstRender = true // screen is black until first touch if we don't check for this
    private static var frameTimer = Timer()

    /// Returns: time taken (in milliseconds) to render current frame
    fileprivate static func render() -> Double {
        doRender(at: frameTimer)
        if shouldQuit { return -1.0 }

        let remainingFrameTime = maxFrameRenderTimeInSeconds - frameTimer.elapsedTimeInSeconds
        if !firstRender, remainingFrameTime > 0 {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, remainingFrameTime, true)
        }

        defer { frameTimer = Timer() } // reset for next frame - XXX: should we do this at the start of the frame instead?
        return round(frameTimer.elapsedTimeInMilliseconds)
    }

    private static func doRender(at frameTimer: Timer) {
        let eventWasHandled = handleEventsIfNeeded()
        if shouldQuit { return }

        if !DisplayLink.activeDisplayLinks.isEmpty {
            DisplayLink.activeDisplayLinks.forEach { $0.callback() }
        } else if !eventWasHandled && !firstRender && !UIView.animationsArePending {
            // Sleep unless there are active touch inputs or pending animations
            return
        }

        UIView.animateIfNeeded(at: frameTimer)

        window.clear()
        rootView.sdlRender()
        window.flip()

        firstRender = false
    }

    private static func handleEventsIfNeeded() -> Bool {
        var eventWasHandled = false
        var e = SDL_Event()

        while SDL_PollEvent(&e) == 1 {
            switch SDL_EventType(rawValue: e.type) {
            case SDL_QUIT:
                print("SDL_QUIT was called")
                shouldQuit = true
                SDL.rootView = UIWindow()
                window = nil
                unload()
            case SDL_MOUSEBUTTONDOWN:
                handleTouchDown(.from(e.button))
                eventWasHandled = true
            case SDL_MOUSEMOTION:
                handleTouchMove(.from(e.motion))
                eventWasHandled = true
            case SDL_MOUSEBUTTONUP:
                handleTouchUp(.from(e.button))
                eventWasHandled = true
            default: break
            }
        }

        return eventWasHandled
    }
}

@_silgen_name("Java_org_libsdl_app_SDLActivity_render")
public func renderCalledFromJava(env: UnsafeMutablePointer<JNIEnv>, view: JavaObject) -> JavaInt {
    return JavaInt(SDL.render())
}
