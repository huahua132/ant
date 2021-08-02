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

#ifndef RMLUI_CORE_DATAVIEWDEFAULT_H
#define RMLUI_CORE_DATAVIEWDEFAULT_H

#include "../Include/RmlUi/Header.h"
#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Variant.h"
#include "DataView.h"

namespace Rml {

class Element;
class DataExpression;
using DataExpressionPtr = std::unique_ptr<DataExpression>;


class DataViewCommon : public DataView {
public:
	DataViewCommon(Element* element, std::string override_modifier = std::string());

	bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& modifier) override;

	std::vector<std::string> GetVariableNameList() const override;

protected:
	const std::string& GetModifier() const;
	DataExpression& GetExpression();

	// Delete this
	void Release() override;

private:
	std::string modifier;
	DataExpressionPtr expression;
};


class DataViewAttribute : public DataViewCommon {
public:
	DataViewAttribute(Element* element);
	DataViewAttribute(Element* element, std::string override_attribute);

	bool Update(DataModel& model) override;
};

class DataViewAttributeIf final : public DataViewCommon {
public:
	DataViewAttributeIf(Element* element);

	bool Update(DataModel& model) override;
};

class DataViewValue final : public DataViewAttribute {
public:
	DataViewValue(Element* element);
};

class DataViewStyle final : public DataViewCommon {
public:
	DataViewStyle(Element* element);

	bool Update(DataModel& model) override;
};


class DataViewClass final : public DataViewCommon {
public:
	DataViewClass(Element* element);

	bool Update(DataModel& model) override;
};


class DataViewRml final : public DataViewCommon {
public:
	DataViewRml(Element* element);

	bool Update(DataModel& model) override;

private:
	std::string previous_rml;
};


class DataViewIf final : public DataViewCommon {
public:
	DataViewIf(Element* element);

	bool Update(DataModel& model) override;
};


class DataViewVisible final : public DataViewCommon {
public:
	DataViewVisible(Element* element);

	bool Update(DataModel& model) override;
};


class DataViewText final : public DataView {
public:
	DataViewText(Element* in_element);

	bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& modifier) override;

	bool Update(DataModel& model) override;
	std::vector<std::string> GetVariableNameList() const override;

protected:
	void Release() override;

private:
	std::string BuildText() const;

	struct DataEntry {
		size_t index = 0; // Index into 'text'
		DataExpressionPtr data_expression;
		std::string value;
	};

	std::string text;
	std::vector<DataEntry> data_entries;
};


class DataViewFor final : public DataView {
public:
	DataViewFor(Element* element);

	bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& inner_rml) override;

	bool Update(DataModel& model) override;

	std::vector<std::string> GetVariableNameList() const override;

protected:
	void Release() override;

private:
	DataAddress container_address;
	std::string iterator_name;
	std::string iterator_index_name;
	std::string rml_contents;
	ElementAttributes attributes;

	ElementList elements;
};

} // namespace Rml
#endif
