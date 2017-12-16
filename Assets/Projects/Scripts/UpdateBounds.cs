using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class UpdateBounds : MonoBehaviour {

    Bounds bound;
    float heightMax;
    
    public void OnEnable()
    {
        bound = GetComponent<MeshFilter>().sharedMesh.bounds;
    }
    private void Update()
    {
        float displacement = GetComponent<Renderer>().sharedMaterial.GetFloat("_Displacement");
        print("current displacement " + displacement);
        GetComponent<MeshFilter>().sharedMesh.bounds = new Bounds(bound.center + Vector3.up * displacement/2f, bound.size + Vector3.up * displacement);
    }
}
