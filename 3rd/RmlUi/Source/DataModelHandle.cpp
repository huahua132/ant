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

#include "../Include/RmlUi/DataModelHandle.h"
#include "DataModel.h"

namespace Rml {


DataModelHandle::DataModelHandle(DataModel* model) : model(model)
{}

bool DataModelHandle::IsVariableDirty(const std::string& variable_name) {
	return model->IsVariableDirty(variable_name);
}

void DataModelHandle::DirtyVariable(const std::string& variable_name) {
	model->DirtyVariable(variable_name);
}


DataModelConstructor::DataModelConstructor() : model(nullptr) {}

DataModelConstructor::DataModelConstructor(DataModel* model) : model(model) {
	RMLUI_ASSERT(model);
}

DataModelHandle DataModelConstructor::GetModelHandle() const {
	return DataModelHandle(model);
}

bool DataModelConstructor::BindFunc(const std::string& name, DataGetFunc get_func, DataSetFunc set_func) {
	return model->BindFunc(name, std::move(get_func), std::move(set_func));
}

bool DataModelConstructor::BindEventCallback(const std::string& name, DataEventFunc event_func) {
	return model->BindEventCallback(name, std::move(event_func));
}

bool DataModelConstructor::BindVariable(const std::string& name, DataVariable data_variable) {
	return model->BindVariable(name, data_variable);
}

} // namespace Rml
