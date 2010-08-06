/*
    SDL - Simple DirectMedia Layer
    Copyright (C) 2010 Eli Gottlieb

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

    Eli Gottlieb
    eligottlieb@gmail.com
*/

#include "SDL_assert.h"
#include "SDL_stdinc.h"
#include "SDL_cocoavideo.h"
#include "SDL_shape.h"
#include "SDL_cocoashape.h"
#include "../SDL_sysvideo.h"

SDL_WindowShaper* Cocoa_CreateShaper(SDL_Window* window) {
	SDL_WindowData* data = (SDL_WindowData*)window->driverdata;
	[data->nswindow setOpaque:NO];
	[data->nswindow setBackgroundColor:[NSColor clearColor]];
	[data->nswindow setStyleMask:NSBorderlessWindowMask];
	SDL_WindowShaper* result = SDL_malloc(sizeof(SDL_WindowShaper));
	result->window = window;
	result->mode.mode = ShapeModeDefault;
	result->mode.parameters.binarizationCutoff = 1;
	result->usershownflag = 0;
	window->shaper = result;
	
	SDL_ShapeData* shape_data = SDL_malloc(sizeof(SDL_ShapeData));
	result->driverdata = shape_data;
	shape_data->context = [data->nswindow graphicsContext];
	SDL_assert(shape_data->context != NULL);
	shape_data->saved = SDL_FALSE;
	shape_data->shape = NULL;
	
	int resized_properly = Cocoa_ResizeWindowShape(window);
	SDL_assert(resized_properly == 0);
	return result;
}

typedef struct {
	NSBezierPath* clipPath;
	SDL_Window* window;
} SDL_PathConglomeration;

NSRect convert_rect(SDL_Rect rect,SDL_Window* window) {
	NSRect nsrect = NSMakeRect(rect.x,window->h-(rect.y+rect.h),rect.w,rect.h);
	return [[((SDL_WindowData*)window->driverdata)->nswindow contentView] convertRectFromBase:nsrect];
}

void ConglomerateShapeTree(SDL_ShapeTree* tree,SDL_PathConglomeration* cong) {
	SDL_assert(tree != NULL);
	if(tree->kind == OpaqueShape) {
		NSRect rect = convert_rect(tree->data.shape,cong->window);
		[cong->clipPath appendBezierPathWithRect:rect];
	}
}

int Cocoa_SetWindowShape(SDL_WindowShaper *shaper,SDL_Surface *shape,SDL_WindowShapeMode *shapeMode) {
	SDL_ShapeData* data = (SDL_ShapeData*)shaper->driverdata;
	/* if(data->saved == SDL_TRUE) {
		[data->context restoreGraphicsState];
		data->saved = SDL_FALSE;
	}*/
		
	/*[data->context saveGraphicsState];
	data->saved = SDL_TRUE;*/
	
	[NSGraphicsContext saveGraphicsState];
	
	[NSGraphicsContext setCurrentContext:data->context];
	SDL_WindowData* window_data = (SDL_WindowData*)shaper->window->driverdata;
	
	data->shape = SDL_CalculateShapeTree(*shapeMode,shape,SDL_FALSE);
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSBezierPath* clipPath = [NSBezierPath bezierPath];
	
	SDL_PathConglomeration cong = {clipPath,shaper->window};
	
	SDL_TraverseShapeTree(data->shape,(SDL_TraversalFunction)&ConglomerateShapeTree,(void*)&cong);
	
	SDL_assert([NSGraphicsContext currentContext] != Nil);
	[clipPath addClip];
	
	[NSGraphicsContext restoreGraphicsState];
	[pool release];
}

int Cocoa_ResizeWindowShape(SDL_Window *window) {
	SDL_ShapeData* data = window->shaper->driverdata;
	SDL_assert(data != NULL);
	
	if(data->shape != NULL)
		SDL_FreeShapeTree(&data->shape);
	
	return 0;
}
