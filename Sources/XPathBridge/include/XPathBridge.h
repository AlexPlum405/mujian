#ifndef XPATH_BRIDGE_H
#define XPATH_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    char *text;
    char *href;
    char *html;
} XPathResult;

typedef struct {
    XPathResult *items;
    size_t count;
} XPathResultList;

XPathResultList xpath_evaluate(const char *html, const char *xpath);
void xpath_result_list_free(XPathResultList list);

#endif
