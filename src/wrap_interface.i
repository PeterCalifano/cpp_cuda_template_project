//*************************************************************************
// MATLAB/Python wrapper definition file.
//*************************************************************************

namespace cpp_playground
{

#include <template_project/utils/wrap_adapters/GtsamAliases.h>
#include <template_project/wrapped_impl/CWrapperPlaceholder.h>

    class CWrapperPlaceholder
    {
        CWrapperPlaceholder();
        double getDataMember() const;
        void setDataMember(const double value);
        string getTextData() const;
        void setTextDataByConstRef(const string &charValue);
        void setTextDataByValue(string charValue);
        uint32_t echoFrameId(uint32_t ui32FrameId) const;
        void printToStdout() const;
        static double multiplyBy2(const double value);
    };

} // ACHTUNG: do not add semi-colon here!
