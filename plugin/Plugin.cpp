
#include "Plugin.h"
#include <iostream>
#include <CommonDependency.h>
#include "SoKwel.h"

namespace kwel {

    void Plugin::doThings() const {
        SoKwel soKwel;
        soKwel.soKwel();
        common::CommonDependency common;
        common.sayHello();
    }

}