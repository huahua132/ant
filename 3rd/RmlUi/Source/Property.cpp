/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/PropertyDefinition.h"

namespace Rml {

Property::Property() : unit(UNKNOWN), specificity(-1)
{
	definition = nullptr;
	parser_index = -1;
}

std::string Property::ToString() const
{
	if (!definition)
		return value.Get< std::string >();

	std::string string;
	definition->GetValue(string, *this);
	return string;
}

FloatValue Property::ToFloatValue() const {
	if (unit & Property::KEYWORD) {
		switch (Get<int>()) {
		default:
		case 0 /* left/top     */: return { 0.0f, Property::Unit::PERCENT }; break;
		case 1 /* center       */: return { 50.0f, Property::Unit::PERCENT }; break;
		case 2 /* right/bottom */: return { 100.0f, Property::Unit::PERCENT }; break;
		}
	}
	return {
		value.Get<float>(),
		unit,
	};
}

} // namespace Rml
