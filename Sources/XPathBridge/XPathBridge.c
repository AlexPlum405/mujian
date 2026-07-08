#include "XPathBridge.h"
#include <libxml/HTMLparser.h>
#include <libxml/HTMLtree.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>
#include <libxml/uri.h>
#include <stdlib.h>
#include <string.h>

static char *dup_string(const char *src) {
    if (!src) return NULL;
    size_t len = strlen(src) + 1;
    char *dst = (char *)malloc(len);
    if (dst) memcpy(dst, src, len);
    return dst;
}

XPathResultList xpath_evaluate(const char *html, const char *xpath) {
    XPathResultList result = { NULL, 0 };
    if (!html || !xpath) return result;

    htmlDocPtr doc = htmlReadMemory(html, strlen(html), "", NULL,
                                    HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING | HTML_PARSE_RECOVER | HTML_PARSE_NONET);
    if (!doc) return result;

    xmlXPathContextPtr ctx = xmlXPathNewContext(doc);
    if (!ctx) {
        xmlFreeDoc(doc);
        return result;
    }

    xmlXPathObjectPtr obj = xmlXPathEvalExpression((const xmlChar *)xpath, ctx);
    if (!obj) {
        xmlXPathFreeContext(ctx);
        xmlFreeDoc(doc);
        return result;
    }

    xmlNodeSetPtr nodes = obj->nodesetval;
    if (!nodes || nodes->nodeNr == 0) {
        xmlXPathFreeObject(obj);
        xmlXPathFreeContext(ctx);
        xmlFreeDoc(doc);
        return result;
    }

    int count = nodes->nodeNr;
    result.items = (XPathResult *)calloc(count, sizeof(XPathResult));
    if (!result.items) {
        xmlXPathFreeObject(obj);
        xmlXPathFreeContext(ctx);
        xmlFreeDoc(doc);
        return result;
    }

    for (int i = 0; i < count; i++) {
        xmlNodePtr node = nodes->nodeTab[i];
        if (!node) continue;

        xmlChar *content = xmlNodeGetContent(node);
        if (content) {
            result.items[i].text = dup_string((const char *)content);
            xmlFree(content);
        }

        xmlChar *href = xmlGetProp(node, (const xmlChar *)"href");
        if (href) {
            result.items[i].href = dup_string((const char *)href);
            xmlFree(href);
        }

        xmlBufferPtr buf = xmlBufferCreate();
        if (buf) {
            htmlNodeDump(buf, doc, node);
            if (buf->content) {
                result.items[i].html = dup_string((const char *)buf->content);
            }
            xmlBufferFree(buf);
        }
    }
    result.count = count;

    xmlXPathFreeObject(obj);
    xmlXPathFreeContext(ctx);
    xmlFreeDoc(doc);
    return result;
}

void xpath_result_list_free(XPathResultList list) {
    if (!list.items) return;
    for (size_t i = 0; i < list.count; i++) {
        if (list.items[i].text) free(list.items[i].text);
        if (list.items[i].href) free(list.items[i].href);
        if (list.items[i].html) free(list.items[i].html);
    }
    free(list.items);
}
