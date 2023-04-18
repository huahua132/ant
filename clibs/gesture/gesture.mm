#include <lua.hpp>
#include "ios/window.h"
#include <queue>
#include <mutex>

extern "C" {
#include <lua-seri.h>
}

static std::queue<void*> g_queue;
static std::mutex        g_mutex;

static void queue_push(void* data) {
    std::unique_lock<std::mutex> _(g_mutex);
    g_queue.push(data);
}

static void* queue_pop() {
    std::unique_lock<std::mutex> _(g_mutex);
    if (g_queue.empty()) {
        return NULL;
    }
    void* data = g_queue.front();
    g_queue.pop();
    return data;
}

template <typename T>
void push_value(lua_State* L, T v);

template <>
void push_value<NSString*>(lua_State* L, NSString* v) {
    lua_pushstring(L, [v UTF8String]);
}

template <>
void push_value<UIGestureRecognizerState>(lua_State* L, UIGestureRecognizerState v) {
    switch (v) {
    case UIGestureRecognizerStatePossible:
        lua_pushstring(L, "possible");
        break;
    case UIGestureRecognizerStateBegan:
        lua_pushstring(L, "began");
        break;
    case UIGestureRecognizerStateChanged:
        lua_pushstring(L, "changed");
        break;
    case UIGestureRecognizerStateEnded:
        lua_pushstring(L, "ended");
        break;
    case UIGestureRecognizerStateCancelled:
        lua_pushstring(L, "cancelled");
        break;
    case UIGestureRecognizerStateFailed:
        lua_pushstring(L, "failed");
        break;
    default:
        lua_pushstring(L, "unknown");
        break;
    }
}

template <typename T>
    requires (std::is_floating_point_v<T>)
void push_value(lua_State* L, T v) {
    lua_pushnumber(L, static_cast<lua_Number>(v));
}

static NSString* lua_getnsstring(lua_State* L, int idx, const char* field, NSString* def) {
    if (LUA_TSTRING != lua_getfield(L, idx, field)) {
        lua_pop(L, 1);
        return def;
    }
    NSString* r = [NSString stringWithUTF8String:lua_tostring(L, -1)];
    lua_pop(L, 1);
    return r;
}

template <typename T>
    requires (std::is_integral_v<T>)
void set_arg(lua_State* L, const char* field, std::function<void(T)> func) {
    if (LUA_TNUMBER != lua_getfield(L, 1, field)) {
        lua_pop(L, 1);
        return;
    }
    if (!lua_isinteger(L, -1)) {
        lua_pop(L, 1);
        return;
    }
    lua_Integer r = lua_tointeger(L, -1);
    lua_pop(L, 1);
    func(static_cast<T>(r));
}

template <typename T>
    requires (std::is_floating_point_v<T>)
void set_arg(lua_State* L, const char* field, std::function<void(T)> func) {
    if (LUA_TNUMBER != lua_getfield(L, 1, field)) {
        lua_pop(L, 1);
        return;
    }
    lua_Number r = lua_tonumber(L, -1);
    lua_pop(L, 1);
    func(static_cast<T>(r));
}

static void add_gesture(UIGestureRecognizer* gesture) {
    CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes,
    ^{
        [global_window addGestureRecognizer:gesture];
    });
}

@interface LuaTapGesture : UITapGestureRecognizer {
    NSString* name;
}
@end
@implementation LuaTapGesture
@end

@interface LuaLongPressGesture : UILongPressGestureRecognizer {
    NSString* name;
}
@end
@implementation LuaLongPressGesture
@end

@interface LuaGestureHandler : NSObject {
    @public lua_State* L;
}
@end
@implementation LuaGestureHandler
-(void)handleTap:(LuaTapGesture *)gesture {
    CGPoint pt = [gesture locationInView:global_window];
    pt.x *= global_window.contentScaleFactor;
    pt.y *= global_window.contentScaleFactor;
    lua_settop(L, 0);
    push_value(L, [gesture name]);
    push_value(L, gesture.state);
    push_value(L, pt.x);
    push_value(L, pt.y);
    void* data = seri_pack(L, 0, NULL);
    queue_push(data);
}
-(void)handleLongPress:(LuaLongPressGesture *)gesture {
    CGPoint pt = [gesture locationInView:global_window];
    pt.x *= global_window.contentScaleFactor;
    pt.y *= global_window.contentScaleFactor;
    lua_settop(L, 0);
    push_value(L, [gesture name]);
    push_value(L, gesture.state);
    push_value(L, pt.x);
    push_value(L, pt.y);
    void* data = seri_pack(L, 0, NULL);
    queue_push(data);
}
@end

static int ltap(lua_State* L) {
    if (!global_window) {
        return luaL_error(L, "window not initialized.");
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    id handler = (__bridge id)lua_touserdata(L, lua_upvalueindex(1));
    LuaTapGesture* gesture = [[LuaTapGesture alloc] initWithTarget:handler action:@selector(handleTap:)];
    gesture.name = lua_getnsstring(L, 1, "name", @"tap");
    set_arg<NSUInteger>(L, "numberOfTapsRequired", [&](auto v){
        gesture.numberOfTapsRequired = v;
    });
    set_arg<NSUInteger>(L, "numberOfTouchesRequired", [&](auto v){
        gesture.numberOfTouchesRequired = v;
    });
    add_gesture(gesture);
    return 0;
}

static int llong_press(lua_State* L) {
    if (!global_window) {
        return luaL_error(L, "window not initialized.");
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    id handler = (__bridge id)lua_touserdata(L, lua_upvalueindex(1));
    LuaLongPressGesture* gesture = [[LuaLongPressGesture alloc] initWithTarget:handler action:@selector(handleLongPress:)];
    gesture.name = lua_getnsstring(L, 1, "name", @"long_press");
    set_arg<NSUInteger>(L, "numberOfTapsRequired", [&](auto v){
        gesture.numberOfTapsRequired = v;
    });
    set_arg<NSUInteger>(L, "numberOfTouchesRequired", [&](auto v){
        gesture.numberOfTouchesRequired = v;
    });
    set_arg<NSTimeInterval>(L, "minimumPressDuration", [&](auto v){
        gesture.minimumPressDuration = v;
    });
    set_arg<CGFloat>(L, "allowableMovement", [&](auto v){
        gesture.allowableMovement = v;
    });
    add_gesture(gesture);
    return 0;
}

static int levent(lua_State* L) {
    void* data = queue_pop();
    if (!data) {
        return 0;
    }
    return seri_unpackptr(L, data);
}

extern "C"
int luaopen_gesture(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "tap", ltap },
        { "long_press", llong_press },
        { "event", levent },
        { NULL, NULL },
    };
    luaL_newlibtable(L, l);
    LuaGestureHandler* handler = [[LuaGestureHandler alloc] init];
    lua_pushlightuserdata(L, (__bridge_retained void*)handler);
    lua_newthread(L);
    handler->L = lua_tothread(L, -1);
    luaL_setfuncs(L, l, 2);
    return 1;
}
