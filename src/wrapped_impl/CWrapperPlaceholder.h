#pragma once
#include <iostream>
#include <concepts>

namespace cpp_playground
{
    // Define type concept for placeholder
    template <typename T>
    concept IsNumericFloatType = requires(T a)
    {   
        std::is_arithmetic_v<T> == true && std::is_floating_point_v<T> == true;
    };

    template <typename T>
    class CWrapperPlaceholder
    {
      public:
        // Public methods
        T getDataMember() const
        {
            return a_float_number;
        }

        T setDataMember()
        {
            return a_float_number;
        }

      public:
        // Public data members
        T a_float_number{0.0};

      public:
        static void multiplyBy2(T &value)
        {
            value *= 2;
        }
    };

}; // namespace cpp_playground